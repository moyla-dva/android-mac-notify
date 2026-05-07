package com.vainve.androidmacnotify.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val DarkColorScheme = darkColorScheme(
    primary = RelayBlue80,
    secondary = RelayGreen80,
    tertiary = RelayAmber80,
    error = RelayError80,
    primaryContainer = RelayBlue30,
    secondaryContainer = RelayGreen30,
    tertiaryContainer = RelayAmber30,
    errorContainer = RelayError30,
    onPrimary = RelayBlue30,
    onSecondary = RelayGreen30,
    onTertiary = RelayAmber30,
    onError = RelayError30,
    onPrimaryContainer = RelayBlueContainer,
    onSecondaryContainer = RelayGreenContainer,
    onTertiaryContainer = RelayAmberContainer,
    onErrorContainer = Color(0xFFFFDAD6),
    background = RelayDarkBackground,
    surface = RelayDarkSurface,
    surfaceVariant = RelayDarkSurfaceVariant,
    onBackground = RelayDarkOnSurface,
    onSurface = RelayDarkOnSurface,
    onSurfaceVariant = RelayDarkOnSurfaceVariant,
)

private val LightColorScheme = lightColorScheme(
    primary = RelayBlue40,
    secondary = RelayGreen40,
    tertiary = RelayAmber40,
    primaryContainer = RelayBlueContainer,
    secondaryContainer = RelayGreenContainer,
    tertiaryContainer = RelayAmberContainer,
    onPrimaryContainer = RelayOnBlueContainer,
    onSecondaryContainer = RelayOnGreenContainer,
    onTertiaryContainer = RelayOnAmberContainer,
    background = RelayBackground,
    surface = RelaySurface,
    surfaceVariant = RelaySurfaceVariant,
    onBackground = RelayOnSurface,
    onSurface = RelayOnSurface,
    onSurfaceVariant = RelayOnSurfaceVariant,
    onPrimary = Color.White,
    onSecondary = Color.White,
    onTertiary = Color.White,
)

@Composable
fun AndroidMacNotifyTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }

        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
