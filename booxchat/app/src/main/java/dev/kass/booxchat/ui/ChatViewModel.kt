package dev.kass.booxchat.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.kass.booxchat.data.Message
import dev.kass.booxchat.data.OpenAIService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class ChatUiState(
    val messages: List<Message> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

class ChatViewModel : ViewModel() {

    private val systemPrompt = Message(
        role = "system",
        content = "You are a helpful assistant."
    )

    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    fun sendMessage(text: String) {
        val trimmed = text.trim()
        if (trimmed.isBlank()) return

        val userMsg = Message(role = "user", content = trimmed)

        _uiState.update { it.copy(messages = it.messages + userMsg, isLoading = true, error = null) }

        viewModelScope.launch {
            try {
                val history = listOf(systemPrompt) + _uiState.value.messages
                val reply = withContext(Dispatchers.IO) {
                    OpenAIService.sendMessages(history)
                }
                val assistantMsg = Message(role = "assistant", content = reply)
                _uiState.update { it.copy(messages = it.messages + assistantMsg, isLoading = false) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = e.message ?: "Unknown error") }
            }
        }
    }

    fun clearConversation() {
        _uiState.update { ChatUiState() }
    }

    fun dismissError() {
        _uiState.update { it.copy(error = null) }
    }
}
