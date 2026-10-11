package org.sokohiki.kimura.app.soracom.gpsmultiunit

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Locale

class MessageI18nTest {
    @Test
    fun `send success message is localized by language`() {
        withLocale("en-US") {
            assertEquals("Send succeeded", MessageI18n.sendSuccess())
        }
        withLocale("de-DE") {
            assertEquals("Senden erfolgreich", MessageI18n.sendSuccess())
        }
        withLocale("es-ES") {
            assertEquals("Envío exitoso", MessageI18n.sendSuccess())
        }
        withLocale("it-IT") {
            assertEquals("Invio riuscito", MessageI18n.sendSuccess())
        }
        withLocale("fr-FR") {
            assertEquals("Envoi réussi", MessageI18n.sendSuccess())
        }
        withLocale("ko-KR") {
            assertEquals("전송 성공", MessageI18n.sendSuccess())
        }
        withLocale("zh-CN") {
            assertEquals("发送成功", MessageI18n.sendSuccess())
        }
        withLocale("ja-JP") {
            assertEquals("送信成功", MessageI18n.sendSuccess())
        }
    }

    @Test
    fun `unsupported language falls back to japanese`() {
        withLocale("pt-BR") {
            assertEquals("送信成功", MessageI18n.sendSuccess())
        }
    }

    @Test
    fun `status and log labels are localized`() {
        withLocale("fr-FR") {
            assertEquals("État", MessageI18n.status())
            assertEquals("Température", MessageI18n.temperature())
            assertEquals("Humidité", MessageI18n.humidity())
            assertEquals("Accélération", MessageI18n.acceleration())
            assertEquals("Envoi manuel", MessageI18n.manualSend())
            assertEquals("Journaux d'envoi", MessageI18n.sendLogs())
            assertEquals("Effacer", MessageI18n.clear())
        }
    }

    @Test
    fun `stored messages are rendered using the current locale`() {
        val message = MessageI18n.Message(MessageI18n.MessageKey.GPS_PERMISSION_DENIED)
        val failedLogMessage = SoracomArcError.SendFailed(
            MessageI18n.Message(MessageI18n.MessageKey.EMPTY_RESPONSE)
        ).uiMessage

        withLocale("en-US") {
            assertEquals(
                "GPS values will not be sent because location permission is not granted.",
                MessageI18n.text(message),
            )
            assertEquals("Send failed: Response was empty.", MessageI18n.text(failedLogMessage))
        }
        withLocale("fr-FR") {
            assertEquals(
                "Les valeurs GPS ne seront pas envoyées, car l'autorisation de localisation n'est pas accordée.",
                MessageI18n.text(message),
            )
            assertEquals("Échec de l'envoi : La réponse était vide.", MessageI18n.text(failedLogMessage))
        }
    }

    private fun withLocale(languageTag: String, block: () -> Unit) {
        val previous = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag(languageTag))
            block()
        } finally {
            Locale.setDefault(previous)
        }
    }
}
