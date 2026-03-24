package dev.kass.booxchat.data

import dev.kass.booxchat.BuildConfig
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

object OpenAIService {

    private const val API_URL = "https://api.openai.com/v1/chat/completions"
    const val MODEL = "gpt-4o"

    private val json = Json { ignoreUnknownKeys = true }

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    // ── Request/Response shapes ───────────────────────────────────────────────

    @Serializable
    private data class ChatMessage(val role: String, val content: String)

    @Serializable
    private data class ChatRequest(
        val model: String,
        val messages: List<ChatMessage>,
        val temperature: Double = 0.7
    )

    @Serializable
    private data class ChatResponse(val choices: List<Choice>)

    @Serializable
    private data class Choice(val message: ChatMessage)

    // ── Public API ────────────────────────────────────────────────────────────

    /**
     * Send the full conversation history and return the assistant's reply,
     * or throw an exception with a human-readable message on failure.
     */
    suspend fun sendMessages(messages: List<Message>): String {
        val payload = ChatRequest(
            model = MODEL,
            messages = messages.map { ChatMessage(it.role, it.content) }
        )

        val body = json.encodeToString(payload)
            .toRequestBody("application/json".toMediaType())

        val request = Request.Builder()
            .url(API_URL)
            .addHeader("Authorization", "Bearer ${BuildConfig.OPENAI_API_KEY}")
            .addHeader("Content-Type", "application/json")
            .post(body)
            .build()

        // OkHttp blocking call — must be called from a background coroutine
        val response = client.newCall(request).execute()
        val responseBody = response.body?.string()
            ?: throw IllegalStateException("Empty response body")

        if (!response.isSuccessful) {
            throw IllegalStateException("OpenAI error ${response.code}: $responseBody")
        }

        val parsed = json.decodeFromString<ChatResponse>(responseBody)
        return parsed.choices.firstOrNull()?.message?.content?.trim()
            ?: throw IllegalStateException("No choices in response")
    }
}
