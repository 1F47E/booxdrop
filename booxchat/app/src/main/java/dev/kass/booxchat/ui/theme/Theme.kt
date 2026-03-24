package dev.kass.booxchat.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// E-ink optimized: pure black/white, no dynamic color, no dark theme.
private val EinkColorScheme = lightColorScheme(
    primary = Color.Black,
    onPrimary = Color.White,
    primaryContainer = Color.Black,
    onPrimaryContainer = Color.White,
    secondary = Color(0xFF444444),
    onSecondary = Color.White,
    background = Color.White,
    onBackground = Color.Black,
    surface = Color.White,
    onSurface = Color.Black,
    surfaceVariant = Color(0xFFF0F0F0),
    onSurfaceVariant = Color.Black,
    outline = Color(0xFF888888),
    error = Color(0xFF880000),
    onError = Color.White,
)

@Composable
fun BooxChatTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = EinkColorScheme,
        content = content
    )
}
