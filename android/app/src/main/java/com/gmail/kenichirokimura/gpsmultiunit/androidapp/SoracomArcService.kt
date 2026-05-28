package com.gmail.kenichirokimura.gpsmultiunit.androidapp

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

sealed class SoracomArcError(message: String) : IllegalStateException(message) {
    class NotConfigured : SoracomArcError("SORACOM Arc が設定されていません。設定画面から WireGuard 接続情報を入力してください。")
    class InvalidConfiguration(detail: String) : SoracomArcError("設定が無効です: $detail")
    class SendFailed(detail: String) : SoracomArcError("送信に失敗しました: $detail")
    class LibraryUnavailable(detail: String = DEFAULT_LIBRARY_UNAVAILABLE_MESSAGE) : SoracomArcError(detail)

    companion object {
        const val DEFAULT_LIBRARY_UNAVAILABLE_MESSAGE =
            "libsoratun ライブラリが利用できません。`android/app/src/main/jniLibs/` に libsoratun.so を配置して再ビルドしてください。"
    }
}

interface SoracomArcService {
    val isConfigured: Boolean

    fun configure(arcConfigJson: String)

    suspend fun sendUdp(
        body: String,
        port: Int = UNIFIED_ENDPOINT_PORT,
        timeoutSeconds: Int = UDP_TIMEOUT_SECONDS,
    ): String

    companion object {
        const val UNIFIED_ENDPOINT_PORT = 23080
        const val UDP_TIMEOUT_SECONDS = 6
    }
}

class LibsoratunArcService(
    private val nativeBridge: LibsoratunNativeBridge = LibsoratunJni,
) : SoracomArcService {
    private var arcConfigJson: String? = null

    override val isConfigured: Boolean
        get() = !arcConfigJson.isNullOrBlank()

    override fun configure(arcConfigJson: String) {
        this.arcConfigJson = effectiveConfigJson(arcConfigJson)
    }

    override suspend fun sendUdp(body: String, port: Int, timeoutSeconds: Int): String = withContext(Dispatchers.IO) {
        val config = arcConfigJson ?: throw SoracomArcError.NotConfigured()
        if (!nativeBridge.isLibsoratunAvailable()) {
            throw SoracomArcError.LibraryUnavailable(
                nativeBridge.loadErrorMessage() ?: SoracomArcError.DEFAULT_LIBRARY_UNAVAILABLE_MESSAGE
            )
        }

        val result = nativeBridge.sendUdp(
            configJson = config,
            body = body.toByteArray(Charsets.UTF_8),
            port = port,
            timeoutSeconds = timeoutSeconds,
        ) ?: throw SoracomArcError.SendFailed("レスポンスが null でした")

        requireValidResponse(result)
        result
    }

    private fun effectiveConfigJson(rawConfig: String): String {
        val trimmed = rawConfig.trim()
        if (trimmed.isEmpty()) {
            throw SoracomArcError.NotConfigured()
        }

        if (trimmed.contains("[Interface]")) {
            return parseWireGuardConfig(trimmed).toString()
        }

        val json = try {
            JSONObject(trimmed)
        } catch (_: JSONException) {
            throw SoracomArcError.InvalidConfiguration("WireGuard 設定または有効な JSON を入力してください。")
        }

        val effective = if (!json.has("arcSessionStatus") && json.has("endpoint")) {
            convertSoratunFormat(json)
        } else {
            json
        }

        val arcSession = effective.optJSONObject("arcSessionStatus")
            ?: throw SoracomArcError.InvalidConfiguration(
                "arcSessionStatus フィールドがありません。WireGuard 設定または soratun の arc.json を貼り付けてください。"
            )

        if (arcSession.length() == 0) {
            throw SoracomArcError.InvalidConfiguration("arcSessionStatus が空です。")
        }

        return effective.toString()
    }

    private fun parseWireGuardConfig(config: String): JSONObject {
        var privateKey: String? = null
        var address: String? = null
        var publicKey: String? = null
        var allowedIps: List<String> = emptyList()
        var endpoint: String? = null
        var currentSection: String? = null

        config.lineSequence().forEach { line ->
            val trimmed = line.trim()
            if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
                currentSection = trimmed.removePrefix("[").removeSuffix("]").lowercase()
                return@forEach
            }
            if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                return@forEach
            }

            val delimiterIndex = trimmed.indexOf('=')
            if (delimiterIndex < 0) {
                return@forEach
            }

            val key = trimmed.substring(0, delimiterIndex).trim()
            val value = trimmed.substring(delimiterIndex + 1).trim()

            when (currentSection) {
                "interface" -> when (key) {
                    "PrivateKey" -> privateKey = value
                    "Address" -> address = value
                }

                "peer" -> when (key) {
                    "PublicKey" -> publicKey = value
                    "AllowedIPs" -> {
                        allowedIps = value.split(",")
                            .map { it.trim() }
                            .filter { it.isNotEmpty() }
                    }

                    "Endpoint" -> endpoint = value
                }
            }
        }

        val clientPrivateKey = privateKey
            ?: throw SoracomArcError.InvalidConfiguration(WIRE_GUARD_PARSE_ERROR)
        val clientAddress = address
            ?: throw SoracomArcError.InvalidConfiguration(WIRE_GUARD_PARSE_ERROR)
        val serverPublicKey = publicKey
            ?: throw SoracomArcError.InvalidConfiguration(WIRE_GUARD_PARSE_ERROR)
        val serverEndpoint = endpoint
            ?: throw SoracomArcError.InvalidConfiguration(WIRE_GUARD_PARSE_ERROR)
        if (allowedIps.isEmpty()) {
            throw SoracomArcError.InvalidConfiguration(WIRE_GUARD_PARSE_ERROR)
        }

        return JSONObject(
            mapOf(
                "privateKey" to clientPrivateKey,
                "logLevel" to 1,
                "arcSessionStatus" to JSONObject(
                    mapOf(
                        "arcServerPeerPublicKey" to serverPublicKey,
                        "arcServerEndpoint" to serverEndpoint,
                        "arcAllowedIPs" to JSONArray(allowedIps),
                        "arcClientPeerIpAddress" to clientAddress.substringBefore("/"),
                    )
                ),
            )
        )
    }

    private fun convertSoratunFormat(json: JSONObject): JSONObject {
        val privateKey = json.optString("privateKey")
        val address = json.optString("address")
        val publicKey = json.optString("publicKey")
        val endpoint = json.optString("endpoint")
        val allowedIpsArray = json.optJSONArray("allowedIPs")

        if (privateKey.isBlank() || address.isBlank() || publicKey.isBlank() || endpoint.isBlank() || allowedIpsArray == null || allowedIpsArray.length() == 0) {
            throw SoracomArcError.InvalidConfiguration("soratun 形式の JSON を libsoratun 形式に変換できませんでした")
        }

        val allowedIps = buildList {
            for (index in 0 until allowedIpsArray.length()) {
                val value = allowedIpsArray.optString(index)
                if (value.isNotBlank()) {
                    add(value)
                }
            }
        }
        if (allowedIps.isEmpty()) {
            throw SoracomArcError.InvalidConfiguration("soratun 形式の JSON を libsoratun 形式に変換できませんでした")
        }

        return JSONObject(
            mapOf(
                "privateKey" to privateKey,
                "logLevel" to 1,
                "arcSessionStatus" to JSONObject(
                    mapOf(
                        "arcServerPeerPublicKey" to publicKey,
                        "arcServerEndpoint" to endpoint,
                        "arcAllowedIPs" to JSONArray(allowedIps),
                        "arcClientPeerIpAddress" to address.substringBefore("/"),
                    )
                ),
            )
        )
    }

    private fun requireValidResponse(response: String) {
        if (response.isBlank()) {
            throw SoracomArcError.SendFailed("レスポンスが空でした。")
        }
        val firstCharacter = response.firstOrNull()
        if (firstCharacter != '2' && firstCharacter != '{') {
            throw SoracomArcError.SendFailed("不正なレスポンス: $response")
        }
    }

    private companion object {
        const val WIRE_GUARD_PARSE_ERROR =
            "WireGuard 設定を解析できませんでした。PrivateKey・Address・PublicKey・AllowedIPs・Endpoint が必要です。"
    }
}
