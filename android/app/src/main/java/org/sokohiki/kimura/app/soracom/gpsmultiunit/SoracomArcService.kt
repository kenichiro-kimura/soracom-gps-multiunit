package org.sokohiki.kimura.app.soracom.gpsmultiunit

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

sealed class SoracomArcError(val uiMessage: MessageI18n.Message) : IllegalStateException(MessageI18n.text(uiMessage)) {
    class NotConfigured : SoracomArcError(MessageI18n.Message(MessageI18n.MessageKey.ARC_NOT_CONFIGURED))
    class FallbackDisabled : SoracomArcError(MessageI18n.Message(MessageI18n.MessageKey.ARC_FALLBACK_DISABLED))
    class InvalidConfiguration(detail: MessageI18n.Message) : SoracomArcError(
        MessageI18n.Message(MessageI18n.MessageKey.INVALID_CONFIGURATION, detailMessage = detail)
    ) {
        constructor(detail: String) : this(MessageI18n.Message(MessageI18n.MessageKey.RAW_DETAIL, detail))
    }
    class SendFailed(detail: MessageI18n.Message) : SoracomArcError(
        MessageI18n.Message(MessageI18n.MessageKey.SEND_FAILED_WITH_DETAIL, detailMessage = detail)
    ) {
        constructor(detail: String) : this(MessageI18n.Message(MessageI18n.MessageKey.RAW_DETAIL, detail))
    }
    class LibraryUnavailable(detail: MessageI18n.Message = MessageI18n.Message(MessageI18n.MessageKey.LIBRARY_UNAVAILABLE_DEFAULT)) :
        SoracomArcError(detail) {
        constructor(detail: String) : this(MessageI18n.Message(MessageI18n.MessageKey.RAW_DETAIL, detail))
    }

    companion object {
        val DEFAULT_LIBRARY_UNAVAILABLE_MESSAGE: String
            get() = MessageI18n.libraryUnavailableDefault()
    }
}

interface SoracomArcService {
    val isConfigured: Boolean

    fun configure(arcConfigJson: String)

    suspend fun sendUdp(
        body: String,
        port: Int = UNIFIED_ENDPOINT_PORT,
        timeoutMillis: Int = UDP_TIMEOUT_MILLIS,
    ): String

    companion object {
        const val UNIFIED_ENDPOINT_PORT = 23080
        const val UDP_TIMEOUT_MILLIS = 6_000
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

    override suspend fun sendUdp(body: String, port: Int, timeoutMillis: Int): String = withContext(Dispatchers.IO) {
        val config = arcConfigJson ?: throw SoracomArcError.NotConfigured()
        if (!nativeBridge.isLibsoratunAvailable()) {
            throw SoracomArcError.LibraryUnavailable(
                nativeBridge.loadError() ?: MessageI18n.Message(MessageI18n.MessageKey.LIBRARY_UNAVAILABLE_DEFAULT)
            )
        }

        val result = nativeBridge.sendUdp(
            configJson = config,
            body = body.toByteArray(Charsets.UTF_8),
            port = port,
            timeoutMillis = timeoutMillis,
        ) ?: throw SoracomArcError.SendFailed(MessageI18n.Message(MessageI18n.MessageKey.RESPONSE_WAS_NULL))

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
            throw SoracomArcError.InvalidConfiguration(
                MessageI18n.Message(MessageI18n.MessageKey.WIRE_GUARD_OR_VALID_JSON_REQUIRED)
            )
        }

        val effective = if (!json.has("arcSessionStatus") && json.has("endpoint")) {
            convertSoratunFormat(json)
        } else {
            json
        }

        val arcSession = effective.optJSONObject("arcSessionStatus")
            ?: throw SoracomArcError.InvalidConfiguration(
                MessageI18n.Message(MessageI18n.MessageKey.MISSING_ARC_SESSION_STATUS_FIELD)
            )

        if (arcSession.length() == 0) {
            throw SoracomArcError.InvalidConfiguration(
                MessageI18n.Message(MessageI18n.MessageKey.ARC_SESSION_STATUS_EMPTY)
            )
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
            ?: throw SoracomArcError.InvalidConfiguration(WIRE_GUARD_PARSE_ERROR_MESSAGE)
        val clientAddress = address
            ?: throw SoracomArcError.InvalidConfiguration(WIRE_GUARD_PARSE_ERROR_MESSAGE)
        val serverPublicKey = publicKey
            ?: throw SoracomArcError.InvalidConfiguration(WIRE_GUARD_PARSE_ERROR_MESSAGE)
        val serverEndpoint = endpoint
            ?: throw SoracomArcError.InvalidConfiguration(WIRE_GUARD_PARSE_ERROR_MESSAGE)
        if (allowedIps.isEmpty()) {
            throw SoracomArcError.InvalidConfiguration(WIRE_GUARD_PARSE_ERROR_MESSAGE)
        }

        return JSONObject(
            mapOf(
                "privateKey" to clientPrivateKey,
                "logLevel" to DEFAULT_LOG_LEVEL,
                "arcSessionStatus" to JSONObject(
                    mapOf(
                        "arcServerPeerPublicKey" to serverPublicKey,
                        "arcServerEndpoint" to serverEndpoint,
                        "arcAllowedIPs" to JSONArray(allowedIps),
                        "arcClientPeerIpAddress" to requireClientIpAddress(clientAddress),
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
            throw SoracomArcError.InvalidConfiguration(
                MessageI18n.Message(MessageI18n.MessageKey.SORATUN_CONVERSION_FAILED)
            )
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
            throw SoracomArcError.InvalidConfiguration(
                MessageI18n.Message(MessageI18n.MessageKey.SORATUN_CONVERSION_FAILED)
            )
        }

        return JSONObject(
            mapOf(
                "privateKey" to privateKey,
                "logLevel" to DEFAULT_LOG_LEVEL,
                "arcSessionStatus" to JSONObject(
                    mapOf(
                        "arcServerPeerPublicKey" to publicKey,
                        "arcServerEndpoint" to endpoint,
                        "arcAllowedIPs" to JSONArray(allowedIps),
                        "arcClientPeerIpAddress" to requireClientIpAddress(address),
                    )
                ),
            )
        )
    }

    private fun requireValidResponse(response: String) {
        if (response.isBlank()) {
            throw SoracomArcError.SendFailed(MessageI18n.Message(MessageI18n.MessageKey.EMPTY_RESPONSE))
        }
        val firstCharacter = response.firstOrNull()
        if (firstCharacter != '2' && firstCharacter != '{') {
            throw SoracomArcError.SendFailed(
                MessageI18n.Message(MessageI18n.MessageKey.INVALID_RESPONSE, response)
            )
        }
    }

    private fun requireClientIpAddress(address: String): String {
        if (!address.contains('/')) {
            throw SoracomArcError.InvalidConfiguration(
                MessageI18n.Message(MessageI18n.MessageKey.ADDRESS_MUST_BE_CIDR)
            )
        }
        return address.substringBefore("/")
    }

    private companion object {
        const val DEFAULT_LOG_LEVEL = 1
        val WIRE_GUARD_PARSE_ERROR_MESSAGE = MessageI18n.Message(MessageI18n.MessageKey.WIRE_GUARD_PARSE_ERROR)
        val WIRE_GUARD_PARSE_ERROR: String
            get() = MessageI18n.text(WIRE_GUARD_PARSE_ERROR_MESSAGE)
    }
}
