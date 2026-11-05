package org.sokohiki.kimura.app.soracom.gpsmultiunit

import java.util.Locale

object MessageI18n {
    data class Message(
        val key: MessageKey,
        val detail: String? = null,
        val detailMessage: Message? = null,
    )

    enum class MessageKey {
        GPS_PERMISSION_DENIED,
        LOCATION_PERMISSION_CHECK_FAILED,
        SEND_SUCCESS,
        SEND_FAILED,
        SEND_FAILED_WITH_DETAIL,
        ARC_NOT_CONFIGURED,
        ARC_FALLBACK_DISABLED,
        LIBRARY_UNAVAILABLE_DEFAULT,
        JNI_LOAD_FAILED,
        INVALID_CONFIGURATION,
        RESPONSE_WAS_NULL,
        EMPTY_RESPONSE,
        INVALID_RESPONSE,
        WIRE_GUARD_OR_VALID_JSON_REQUIRED,
        MISSING_ARC_SESSION_STATUS_FIELD,
        ARC_SESSION_STATUS_EMPTY,
        SORATUN_CONVERSION_FAILED,
        ADDRESS_MUST_BE_CIDR,
        WIRE_GUARD_PARSE_ERROR,
        RAW_DETAIL,
    }

    private enum class Language {
        JA, EN, DE, ES, IT, FR, KO, ZH
    }

    private fun language(locale: Locale = Locale.getDefault()): Language {
        val tag = locale.toLanguageTag().lowercase(Locale.ROOT)
        return when {
            tag.startsWith("en") -> Language.EN
            tag.startsWith("de") -> Language.DE
            tag.startsWith("es") -> Language.ES
            tag.startsWith("it") -> Language.IT
            tag.startsWith("fr") -> Language.FR
            tag.startsWith("ko") -> Language.KO
            tag.startsWith("zh") -> Language.ZH
            else -> Language.JA
        }
    }

    fun gpsPermissionDenied(): String = when (language()) {
        Language.EN -> "GPS values will not be sent because location permission is not granted."
        Language.DE -> "GPS-Werte werden nicht gesendet, da keine Standortberechtigung erteilt wurde."
        Language.ES -> "Los valores de GPS no se enviarán porque no se concedió el permiso de ubicación."
        Language.IT -> "I valori GPS non verranno inviati perché non è stata concessa l'autorizzazione alla posizione."
        Language.FR -> "Les valeurs GPS ne seront pas envoyées, car l'autorisation de localisation n'est pas accordée."
        Language.KO -> "위치 권한이 없어 GPS 값은 전송되지 않습니다."
        Language.ZH -> "由于未授予位置权限，GPS 数值不会发送。"
        Language.JA -> "位置情報の権限がないため GPS 値は送信されません。"
    }

    fun locationPermissionCheckFailed(): String = when (language()) {
        Language.EN -> "Could not verify location permission."
        Language.DE -> "Standortberechtigung konnte nicht überprüft werden."
        Language.ES -> "No se pudo verificar el permiso de ubicación."
        Language.IT -> "Impossibile verificare l'autorizzazione alla posizione."
        Language.FR -> "Impossible de vérifier l'autorisation de localisation."
        Language.KO -> "위치 권한을 확인할 수 없었습니다."
        Language.ZH -> "无法确认位置权限。"
        Language.JA -> "位置情報の利用許可を確認できませんでした。"
    }

    fun sendSuccess(): String = when (language()) {
        Language.EN -> "Send succeeded"
        Language.DE -> "Senden erfolgreich"
        Language.ES -> "Envío exitoso"
        Language.IT -> "Invio riuscito"
        Language.FR -> "Envoi réussi"
        Language.KO -> "전송 성공"
        Language.ZH -> "发送成功"
        Language.JA -> "送信成功"
    }

    fun sendFailed(): String = when (language()) {
        Language.EN -> "Send failed."
        Language.DE -> "Senden fehlgeschlagen."
        Language.ES -> "Error al enviar."
        Language.IT -> "Invio non riuscito."
        Language.FR -> "Échec de l'envoi."
        Language.KO -> "전송에 실패했습니다."
        Language.ZH -> "发送失败。"
        Language.JA -> "送信に失敗しました。"
    }

    fun udpFallbackSuffix(): String = when (language()) {
        Language.EN -> " (UDP fallback)"
        Language.DE -> " (UDP-Fallback)"
        Language.ES -> " (respaldo UDP)"
        Language.IT -> " (fallback UDP)"
        Language.FR -> " (secours UDP)"
        Language.KO -> " (UDP 폴백)"
        Language.ZH -> "（UDP 回退）"
        Language.JA -> " (UDP フォールバック)"
    }

    fun arcNotConfigured(): String = when (language()) {
        Language.EN -> "SORACOM Arc is not configured. Enter WireGuard configuration from Settings."
        Language.DE -> "SORACOM Arc ist nicht konfiguriert. Geben Sie die WireGuard-Konfiguration in den Einstellungen ein."
        Language.ES -> "SORACOM Arc no está configurado. Introduce la configuración de WireGuard en Ajustes."
        Language.IT -> "SORACOM Arc non è configurato. Inserisci la configurazione WireGuard dalle Impostazioni."
        Language.FR -> "SORACOM Arc n'est pas configuré. Saisissez la configuration WireGuard depuis les paramètres."
        Language.KO -> "SORACOM Arc가 설정되지 않았습니다. 설정 화면에서 WireGuard 구성을 입력하세요."
        Language.ZH -> "SORACOM Arc 尚未配置。请在设置中输入 WireGuard 配置。"
        Language.JA -> "SORACOM Arc が設定されていません。設定画面から WireGuard 接続情報を入力してください。"
    }

    fun arcFallbackDisabled(): String = when (language()) {
        Language.EN -> "Send failed because SORACOM Arc is unavailable and UDP fallback over the internet is disabled."
        Language.DE -> "Senden fehlgeschlagen, da SORACOM Arc nicht verfügbar ist und der UDP-Fallback über das Internet deaktiviert ist."
        Language.ES -> "Error al enviar: SORACOM Arc no está disponible y el respaldo UDP por Internet está deshabilitado."
        Language.IT -> "Invio non riuscito perché SORACOM Arc non è disponibile e il fallback UDP via Internet è disabilitato."
        Language.FR -> "Échec de l'envoi, car SORACOM Arc est indisponible et le secours UDP via Internet est désactivé."
        Language.KO -> "SORACOM Arc를 사용할 수 없고 인터넷 경유 UDP 폴백이 비활성화되어 전송에 실패했습니다."
        Language.ZH -> "发送失败：SORACOM Arc 不可用，且已禁用互联网 UDP 回退。"
        Language.JA -> "SORACOM Arc を利用できず、インターネット経由 UDP のフォールバックが無効なため送信に失敗しました。"
    }

    fun invalidConfiguration(detail: String): String = when (language()) {
        Language.EN -> "Invalid configuration: $detail"
        Language.DE -> "Ungültige Konfiguration: $detail"
        Language.ES -> "Configuración no válida: $detail"
        Language.IT -> "Configurazione non valida: $detail"
        Language.FR -> "Configuration invalide : $detail"
        Language.KO -> "설정이 올바르지 않습니다: $detail"
        Language.ZH -> "配置无效：$detail"
        Language.JA -> "設定が無効です: $detail"
    }

    fun sendFailedWithDetail(detail: String): String = when (language()) {
        Language.EN -> "Send failed: $detail"
        Language.DE -> "Senden fehlgeschlagen: $detail"
        Language.ES -> "Error al enviar: $detail"
        Language.IT -> "Invio non riuscito: $detail"
        Language.FR -> "Échec de l'envoi : $detail"
        Language.KO -> "전송에 실패했습니다: $detail"
        Language.ZH -> "发送失败：$detail"
        Language.JA -> "送信に失敗しました: $detail"
    }

    fun libraryUnavailableDefault(): String = when (language()) {
        Language.EN -> "libsoratun library is unavailable. Place libsoratun.so in `android/app/src/main/jniLibs/` and rebuild."
        Language.DE -> "Die libsoratun-Bibliothek ist nicht verfügbar. Legen Sie libsoratun.so unter `android/app/src/main/jniLibs/` ab und bauen Sie neu."
        Language.ES -> "La biblioteca libsoratun no está disponible. Coloca libsoratun.so en `android/app/src/main/jniLibs/` y recompila."
        Language.IT -> "La libreria libsoratun non è disponibile. Posiziona libsoratun.so in `android/app/src/main/jniLibs/` e ricompila."
        Language.FR -> "La bibliothèque libsoratun est indisponible. Placez libsoratun.so dans `android/app/src/main/jniLibs/` puis reconstruisez."
        Language.KO -> "libsoratun 라이브러리를 사용할 수 없습니다. `android/app/src/main/jniLibs/`에 libsoratun.so를 배치하고 다시 빌드하세요."
        Language.ZH -> "libsoratun 库不可用。请将 libsoratun.so 放置到 `android/app/src/main/jniLibs/` 并重新构建。"
        Language.JA -> "libsoratun ライブラリが利用できません。`android/app/src/main/jniLibs/` に libsoratun.so を配置して再ビルドしてください。"
    }

    fun responseWasNull(): String = when (language()) {
        Language.EN -> "Response was null."
        Language.DE -> "Antwort war null."
        Language.ES -> "La respuesta fue null."
        Language.IT -> "La risposta era null."
        Language.FR -> "La réponse était null."
        Language.KO -> "응답이 null이었습니다."
        Language.ZH -> "响应为 null。"
        Language.JA -> "レスポンスが null でした"
    }

    fun emptyResponse(): String = when (language()) {
        Language.EN -> "Response was empty."
        Language.DE -> "Antwort war leer."
        Language.ES -> "La respuesta estaba vacía."
        Language.IT -> "La risposta era vuota."
        Language.FR -> "La réponse était vide."
        Language.KO -> "응답이 비어 있었습니다."
        Language.ZH -> "响应为空。"
        Language.JA -> "レスポンスが空でした。"
    }

    fun invalidResponse(response: String): String = when (language()) {
        Language.EN -> "Invalid response: $response"
        Language.DE -> "Ungültige Antwort: $response"
        Language.ES -> "Respuesta no válida: $response"
        Language.IT -> "Risposta non valida: $response"
        Language.FR -> "Réponse invalide : $response"
        Language.KO -> "잘못된 응답: $response"
        Language.ZH -> "无效响应：$response"
        Language.JA -> "不正なレスポンス: $response"
    }

    fun wireGuardOrValidJsonRequired(): String = when (language()) {
        Language.EN -> "Enter WireGuard settings or valid JSON."
        Language.DE -> "Geben Sie WireGuard-Einstellungen oder gültiges JSON ein."
        Language.ES -> "Introduce la configuración de WireGuard o JSON válido."
        Language.IT -> "Inserisci impostazioni WireGuard o JSON valido."
        Language.FR -> "Saisissez les paramètres WireGuard ou un JSON valide."
        Language.KO -> "WireGuard 설정 또는 유효한 JSON을 입력하세요."
        Language.ZH -> "请输入 WireGuard 设置或有效的 JSON。"
        Language.JA -> "WireGuard 設定または有効な JSON を入力してください。"
    }

    fun missingArcSessionStatusField(): String = when (language()) {
        Language.EN -> "arcSessionStatus field is missing. Paste WireGuard settings or soratun arc.json."
        Language.DE -> "Das Feld arcSessionStatus fehlt. Fügen Sie WireGuard-Einstellungen oder soratun arc.json ein."
        Language.ES -> "Falta el campo arcSessionStatus. Pega la configuración de WireGuard o el arc.json de soratun."
        Language.IT -> "Manca il campo arcSessionStatus. Incolla la configurazione WireGuard o il file arc.json di soratun."
        Language.FR -> "Le champ arcSessionStatus est manquant. Collez la configuration WireGuard ou le fichier arc.json de soratun."
        Language.KO -> "arcSessionStatus 필드가 없습니다. WireGuard 설정 또는 soratun arc.json을 붙여넣으세요."
        Language.ZH -> "缺少 arcSessionStatus 字段。请粘贴 WireGuard 设置或 soratun 的 arc.json。"
        Language.JA -> "arcSessionStatus フィールドがありません。WireGuard 設定または soratun の arc.json を貼り付けてください。"
    }

    fun arcSessionStatusEmpty(): String = when (language()) {
        Language.EN -> "arcSessionStatus is empty."
        Language.DE -> "arcSessionStatus ist leer."
        Language.ES -> "arcSessionStatus está vacío."
        Language.IT -> "arcSessionStatus è vuoto."
        Language.FR -> "arcSessionStatus est vide."
        Language.KO -> "arcSessionStatus가 비어 있습니다."
        Language.ZH -> "arcSessionStatus 为空。"
        Language.JA -> "arcSessionStatus が空です。"
    }

    fun soratunConversionFailed(): String = when (language()) {
        Language.EN -> "Could not convert soratun JSON format to libsoratun format."
        Language.DE -> "Das soratun-JSON-Format konnte nicht in das libsoratun-Format konvertiert werden."
        Language.ES -> "No se pudo convertir el JSON de soratun al formato de libsoratun."
        Language.IT -> "Impossibile convertire il JSON in formato soratun nel formato libsoratun."
        Language.FR -> "Impossible de convertir le JSON au format soratun vers le format libsoratun."
        Language.KO -> "soratun 형식 JSON을 libsoratun 형식으로 변환할 수 없습니다."
        Language.ZH -> "无法将 soratun 格式 JSON 转换为 libsoratun 格式。"
        Language.JA -> "soratun 形式の JSON を libsoratun 形式に変換できませんでした"
    }

    fun addressMustBeCidr(): String = when (language()) {
        Language.EN -> "Address must be in CIDR format."
        Language.DE -> "Address muss im CIDR-Format angegeben werden."
        Language.ES -> "Address debe especificarse en formato CIDR."
        Language.IT -> "Address deve essere specificato in formato CIDR."
        Language.FR -> "Address doit être au format CIDR."
        Language.KO -> "Address는 CIDR 형식이어야 합니다."
        Language.ZH -> "Address 必须为 CIDR 格式。"
        Language.JA -> "Address は CIDR 形式で指定してください。"
    }

    fun wireGuardParseError(): String = when (language()) {
        Language.EN -> "Could not parse WireGuard settings. PrivateKey, Address, PublicKey, AllowedIPs and Endpoint are required."
        Language.DE -> "WireGuard-Einstellungen konnten nicht analysiert werden. PrivateKey, Address, PublicKey, AllowedIPs und Endpoint sind erforderlich."
        Language.ES -> "No se pudo analizar la configuración de WireGuard. Se requieren PrivateKey, Address, PublicKey, AllowedIPs y Endpoint."
        Language.IT -> "Impossibile analizzare le impostazioni WireGuard. Sono richiesti PrivateKey, Address, PublicKey, AllowedIPs ed Endpoint."
        Language.FR -> "Impossible d'analyser les paramètres WireGuard. PrivateKey, Address, PublicKey, AllowedIPs et Endpoint sont requis."
        Language.KO -> "WireGuard 설정을 해석할 수 없습니다. PrivateKey, Address, PublicKey, AllowedIPs, Endpoint가 필요합니다."
        Language.ZH -> "无法解析 WireGuard 设置。需要 PrivateKey、Address、PublicKey、AllowedIPs 和 Endpoint。"
        Language.JA -> "WireGuard 設定を解析できませんでした。PrivateKey・Address・PublicKey・AllowedIPs・Endpoint が必要です。"
    }

    fun jniLoadFailed(): String = when (language()) {
        Language.EN -> "Failed to load soratunbridge. Check JNI wrapper and dependent `libsoratun.so`, place it under `android/app/src/main/jniLibs/`, then rebuild."
        Language.DE -> "soratunbridge konnte nicht geladen werden. Überprüfen Sie den JNI-Wrapper und die abhängige `libsoratun.so`, legen Sie sie unter `android/app/src/main/jniLibs/` ab und bauen Sie neu."
        Language.ES -> "No se pudo cargar soratunbridge. Verifica el wrapper JNI y la dependencia `libsoratun.so`, colócala en `android/app/src/main/jniLibs/` y recompila."
        Language.IT -> "Impossibile caricare soratunbridge. Controlla il wrapper JNI e la dipendenza `libsoratun.so`, posizionala in `android/app/src/main/jniLibs/` e ricompila."
        Language.FR -> "Échec du chargement de soratunbridge. Vérifiez le wrapper JNI et la dépendance `libsoratun.so`, placez-la dans `android/app/src/main/jniLibs/`, puis reconstruisez."
        Language.KO -> "soratunbridge를 로드하지 못했습니다. JNI 래퍼와 의존성 `libsoratun.so`를 확인하고 `android/app/src/main/jniLibs/`에 배치한 뒤 다시 빌드하세요."
        Language.ZH -> "加载 soratunbridge 失败。请检查 JNI 包装器和依赖的 `libsoratun.so`，将其放到 `android/app/src/main/jniLibs/` 后重新构建。"
        Language.JA -> "soratunbridge の読み込みに失敗しました。JNI ラッパーまたは依存する `libsoratun.so` を確認し、`android/app/src/main/jniLibs/` に配置して再ビルドしてください。"
    }

    fun connectionStatusLabel(status: ConnectionStatus): String = when (status) {
        ConnectionStatus.DISCONNECTED -> when (language()) {
            Language.EN -> "Waiting"
            Language.DE -> "Bereit"
            Language.ES -> "En espera"
            Language.IT -> "In attesa"
            Language.FR -> "En attente"
            Language.KO -> "대기 중"
            Language.ZH -> "等待中"
            Language.JA -> "送信待機"
        }
        ConnectionStatus.SENDING -> when (language()) {
            Language.EN -> "Sending"
            Language.DE -> "Wird gesendet"
            Language.ES -> "Enviando"
            Language.IT -> "Invio in corso"
            Language.FR -> "Envoi en cours"
            Language.KO -> "전송 중"
            Language.ZH -> "发送中"
            Language.JA -> "送信中"
        }
        ConnectionStatus.CONNECTED -> when (language()) {
            Language.EN -> "Sent"
            Language.DE -> "Gesendet"
            Language.ES -> "Enviado"
            Language.IT -> "Inviato"
            Language.FR -> "Envoyé"
            Language.KO -> "전송 완료"
            Language.ZH -> "发送成功"
            Language.JA -> "送信成功"
        }
        ConnectionStatus.FAILED -> when (language()) {
            Language.EN -> "Failed"
            Language.DE -> "Fehlgeschlagen"
            Language.ES -> "Error"
            Language.IT -> "Errore"
            Language.FR -> "Échec"
            Language.KO -> "실패"
            Language.ZH -> "失败"
            Language.JA -> "送信失敗"
        }
    }

    fun sendTypeLabel(type: SendType): String = when (type) {
        SendType.MANUAL -> when (language()) {
            Language.EN -> "Manual"
            Language.DE -> "Manuell"
            Language.ES -> "Manual"
            Language.IT -> "Manuale"
            Language.FR -> "Manuel"
            Language.KO -> "수동"
            Language.ZH -> "手动"
            Language.JA -> "手動"
        }
        SendType.PERIODIC -> when (language()) {
            Language.EN -> "Periodic"
            Language.DE -> "Periodisch"
            Language.ES -> "Periódico"
            Language.IT -> "Periodico"
            Language.FR -> "Périodique"
            Language.KO -> "주기"
            Language.ZH -> "定期"
            Language.JA -> "定期"
        }
        SendType.ACCELERATION_ALERT -> when (language()) {
            Language.EN -> "Acceleration"
            Language.DE -> "Beschleunigung"
            Language.ES -> "Aceleración"
            Language.IT -> "Accelerazione"
            Language.FR -> "Accélération"
            Language.KO -> "가속도"
            Language.ZH -> "加速度"
            Language.JA -> "加速度"
        }
    }

    fun sendStatusLabel(type: SendType?, isSending: Boolean): String {
        val base = when (type) {
            SendType.PERIODIC -> when (language()) {
                Language.EN -> "Auto send"
                Language.DE -> "Automatisches Senden"
                Language.ES -> "Envío automático"
                Language.IT -> "Invio automatico"
                Language.FR -> "Envoi automatique"
                Language.KO -> "자동 전송"
                Language.ZH -> "自动发送"
                Language.JA -> "自動送信"
            }
            SendType.MANUAL, null -> when (language()) {
                Language.EN -> "Manual send"
                Language.DE -> "Manuelles Senden"
                Language.ES -> "Envío manual"
                Language.IT -> "Invio manuale"
                Language.FR -> "Envoi manuel"
                Language.KO -> "수동 전송"
                Language.ZH -> "手动发送"
                Language.JA -> "手動送信"
            }
            SendType.ACCELERATION_ALERT -> when (language()) {
                Language.EN -> "Acceleration send"
                Language.DE -> "Beschleunigungssenden"
                Language.ES -> "Envío por aceleración"
                Language.IT -> "Invio accelerazione"
                Language.FR -> "Envoi par accélération"
                Language.KO -> "가속도 전송"
                Language.ZH -> "加速度发送"
                Language.JA -> "加速度送信"
            }
        }
        val suffix = when (language()) {
            Language.EN -> "..."
            Language.DE -> "..."
            Language.ES -> "..."
            Language.IT -> "..."
            Language.FR -> "..."
            Language.KO -> " 중..."
            Language.ZH -> "中..."
            Language.JA -> "中…"
        }
        return if (isSending) "$base$suffix" else base
    }

    fun sendLogsEmpty(): String = when (language()) {
        Language.EN -> "No send logs yet"
        Language.DE -> "Noch keine Sendeprotokolle"
        Language.ES -> "Aún no hay registros de envío"
        Language.IT -> "Nessun registro di invio"
        Language.FR -> "Aucun journal d'envoi pour le moment"
        Language.KO -> "아직 전송 로그가 없습니다"
        Language.ZH -> "暂无发送日志"
        Language.JA -> "送信ログはまだありません"
    }

    fun sentSensorValuesMessage(): String = when (language()) {
        Language.EN -> "Sent sensor values."
        Language.DE -> "Sensorwerte wurden gesendet."
        Language.ES -> "Se enviaron los valores del sensor."
        Language.IT -> "Valori del sensore inviati."
        Language.FR -> "Valeurs du capteur envoyées."
        Language.KO -> "센서 값을 전송했습니다."
        Language.ZH -> "已发送传感器值。"
        Language.JA -> "センサー値を送信しました"
    }

    fun lastSentText(lastSentAtLabel: String?): String = when (language()) {
        Language.EN -> "Last sent: ${lastSentAtLabel ?: "Not sent"}"
        Language.DE -> "Letzte Übertragung: ${lastSentAtLabel ?: "Nicht gesendet"}"
        Language.ES -> "Último envío: ${lastSentAtLabel ?: "No enviado"}"
        Language.IT -> "Ultimo invio: ${lastSentAtLabel ?: "Non inviato"}"
        Language.FR -> "Dernier envoi : ${lastSentAtLabel ?: "Non envoyé"}"
        Language.KO -> "마지막 전송: ${lastSentAtLabel ?: "미전송"}"
        Language.ZH -> "最后发送：${lastSentAtLabel ?: "未发送"}"
        Language.JA -> "最終送信: ${lastSentAtLabel ?: "未送信"}"
    }

    fun noSignal(): String = when (language()) {
        Language.EN -> "No signal"
        Language.DE -> "Kein Signal"
        Language.ES -> "Sin señal"
        Language.IT -> "Nessun segnale"
        Language.FR -> "Aucun signal"
        Language.KO -> "신호 없음"
        Language.ZH -> "无信号"
        Language.JA -> "信号なし"
    }

    fun status(): String = when (language()) {
        Language.EN -> "Status"
        Language.DE -> "Status"
        Language.ES -> "Estado"
        Language.IT -> "Stato"
        Language.FR -> "État"
        Language.KO -> "상태"
        Language.ZH -> "状态"
        Language.JA -> "ステータス"
    }

    fun temperature(): String = when (language()) {
        Language.EN -> "Temperature"
        Language.DE -> "Temperatur"
        Language.ES -> "Temperatura"
        Language.IT -> "Temperatura"
        Language.FR -> "Température"
        Language.KO -> "온도"
        Language.ZH -> "温度"
        Language.JA -> "温度"
    }

    fun humidity(): String = when (language()) {
        Language.EN -> "Humidity"
        Language.DE -> "Luftfeuchtigkeit"
        Language.ES -> "Humedad"
        Language.IT -> "Umidità"
        Language.FR -> "Humidité"
        Language.KO -> "습도"
        Language.ZH -> "湿度"
        Language.JA -> "湿度"
    }

    fun acceleration(): String = when (language()) {
        Language.EN -> "Acceleration"
        Language.DE -> "Beschleunigung"
        Language.ES -> "Aceleración"
        Language.IT -> "Accelerazione"
        Language.FR -> "Accélération"
        Language.KO -> "가속도"
        Language.ZH -> "加速度"
        Language.JA -> "加速度"
    }

    fun manualSend(): String = when (language()) {
        Language.EN -> "Manual send"
        Language.DE -> "Manuell senden"
        Language.ES -> "Envío manual"
        Language.IT -> "Invio manuale"
        Language.FR -> "Envoi manuel"
        Language.KO -> "수동 전송"
        Language.ZH -> "手动发送"
        Language.JA -> "手動送信"
    }

    fun sendLogs(): String = when (language()) {
        Language.EN -> "Send logs"
        Language.DE -> "Sendeprotokolle"
        Language.ES -> "Registros de envío"
        Language.IT -> "Registri di invio"
        Language.FR -> "Journaux d'envoi"
        Language.KO -> "전송 로그"
        Language.ZH -> "发送日志"
        Language.JA -> "送信ログ"
    }

    fun clear(): String = when (language()) {
        Language.EN -> "Clear"
        Language.DE -> "Löschen"
        Language.ES -> "Borrar"
        Language.IT -> "Cancella"
        Language.FR -> "Effacer"
        Language.KO -> "지우기"
        Language.ZH -> "清除"
        Language.JA -> "消去"
    }

    fun text(message: Message): String = when (message.key) {
        MessageKey.GPS_PERMISSION_DENIED -> gpsPermissionDenied()
        MessageKey.LOCATION_PERMISSION_CHECK_FAILED -> locationPermissionCheckFailed()
        MessageKey.SEND_SUCCESS -> sendSuccess()
        MessageKey.SEND_FAILED -> sendFailed()
        MessageKey.SEND_FAILED_WITH_DETAIL -> sendFailedWithDetail(message.detailMessage?.let(::text) ?: message.detail.orEmpty())
        MessageKey.ARC_NOT_CONFIGURED -> arcNotConfigured()
        MessageKey.ARC_FALLBACK_DISABLED -> arcFallbackDisabled()
        MessageKey.LIBRARY_UNAVAILABLE_DEFAULT -> libraryUnavailableDefault()
        MessageKey.JNI_LOAD_FAILED -> jniLoadFailed()
        MessageKey.INVALID_CONFIGURATION -> invalidConfiguration(message.detailMessage?.let(::text) ?: message.detail.orEmpty())
        MessageKey.RESPONSE_WAS_NULL -> responseWasNull()
        MessageKey.EMPTY_RESPONSE -> emptyResponse()
        MessageKey.INVALID_RESPONSE -> invalidResponse(message.detail.orEmpty())
        MessageKey.WIRE_GUARD_OR_VALID_JSON_REQUIRED -> wireGuardOrValidJsonRequired()
        MessageKey.MISSING_ARC_SESSION_STATUS_FIELD -> missingArcSessionStatusField()
        MessageKey.ARC_SESSION_STATUS_EMPTY -> arcSessionStatusEmpty()
        MessageKey.SORATUN_CONVERSION_FAILED -> soratunConversionFailed()
        MessageKey.ADDRESS_MUST_BE_CIDR -> addressMustBeCidr()
        MessageKey.WIRE_GUARD_PARSE_ERROR -> wireGuardParseError()
        MessageKey.RAW_DETAIL -> message.detail.orEmpty()
    }
}
