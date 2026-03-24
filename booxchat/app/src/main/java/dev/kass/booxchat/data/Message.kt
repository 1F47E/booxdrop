package dev.kass.booxchat.data

import java.util.UUID

data class Message(
    val id: String = UUID.randomUUID().toString(),
    val role: String,   // "system" | "user" | "assistant"
    val content: String
)
