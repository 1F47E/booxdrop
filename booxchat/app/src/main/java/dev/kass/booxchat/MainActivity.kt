package dev.kass.booxchat

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import dev.kass.booxchat.ui.ChatScreen
import dev.kass.booxchat.ui.theme.BooxChatTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            BooxChatTheme {
                ChatScreen()
            }
        }
    }
}
