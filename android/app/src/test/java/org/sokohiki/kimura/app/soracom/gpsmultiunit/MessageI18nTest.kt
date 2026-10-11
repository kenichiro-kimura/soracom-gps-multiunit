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
        withLocale("fr-FR") {
            assertEquals("送信成功", MessageI18n.sendSuccess())
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
