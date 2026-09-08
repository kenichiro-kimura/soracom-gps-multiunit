package com.gmail.kenichirokimura.gpsmultiunit.androidapp.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val SoracomColorScheme = lightColorScheme(
    primary = SoracomPrimary,
    secondary = SoracomSecondary,
    surface = SoracomSurface,
)

@Composable
fun SoracomGPSMultiunitTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = SoracomColorScheme,
        content = content,
    )
}
