package dev.kass.booxchat.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.kass.booxchat.data.Message
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(vm: ChatViewModel = viewModel()) {
    val uiState by vm.uiState.collectAsState()
    var inputText by remember { mutableStateOf("") }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    // Auto-scroll to bottom whenever messages change
    LaunchedEffect(uiState.messages.size) {
        if (uiState.messages.isNotEmpty()) {
            listState.animateScrollToItem(uiState.messages.size - 1)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("BooxChat", fontSize = 18.sp) },
                actions = {
                    IconButton(onClick = { vm.clearConversation() }) {
                        Icon(Icons.Default.Delete, contentDescription = "Clear conversation")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black,
                    titleContentColor = Color.White,
                    actionIconContentColor = Color.White
                )
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Message list
            LazyColumn(
                state = listState,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(vertical = 12.dp)
            ) {
                items(uiState.messages, key = { it.id }) { message ->
                    MessageBubble(message)
                }
                if (uiState.isLoading) {
                    item {
                        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterStart) {
                            Text(
                                "...",
                                modifier = Modifier
                                    .border(1.dp, Color.Black, RoundedCornerShape(8.dp))
                                    .padding(horizontal = 12.dp, vertical = 8.dp),
                                fontSize = 20.sp,
                                color = Color.Black
                            )
                        }
                    }
                }
            }

            // Error banner
            if (uiState.error != null) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color(0xFFFFEEEE))
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Error: ${uiState.error}",
                        color = Color(0xFF880000),
                        modifier = Modifier.weight(1f),
                        fontSize = 13.sp
                    )
                    TextButton(onClick = { vm.dismissError() }) {
                        Text("Dismiss", color = Color(0xFF880000))
                    }
                }
            }

            HorizontalDivider(color = Color.Black, thickness = 1.dp)

            // Input bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(8.dp),
                verticalAlignment = Alignment.Bottom
            ) {
                OutlinedTextField(
                    value = inputText,
                    onValueChange = { inputText = it },
                    modifier = Modifier.weight(1f),
                    placeholder = { Text("Message…") },
                    maxLines = 5,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color.Black,
                        unfocusedBorderColor = Color(0xFF888888),
                        cursorColor = Color.Black
                    ),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                    keyboardActions = KeyboardActions(onSend = {
                        if (inputText.isNotBlank() && !uiState.isLoading) {
                            vm.sendMessage(inputText)
                            inputText = ""
                        }
                    })
                )
                Spacer(modifier = Modifier.width(8.dp))
                IconButton(
                    onClick = {
                        if (inputText.isNotBlank() && !uiState.isLoading) {
                            vm.sendMessage(inputText)
                            inputText = ""
                            scope.launch { listState.animateScrollToItem(Int.MAX_VALUE) }
                        }
                    },
                    modifier = Modifier
                        .size(48.dp)
                        .background(Color.Black, RoundedCornerShape(8.dp))
                ) {
                    Icon(Icons.Default.Send, contentDescription = "Send", tint = Color.White)
                }
            }
        }
    }
}

@Composable
private fun MessageBubble(message: Message) {
    val isUser = message.role == "user"

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start
    ) {
        if (isUser) {
            Text(
                text = message.content,
                modifier = Modifier
                    .widthIn(max = 300.dp)
                    .background(Color.Black, RoundedCornerShape(12.dp, 2.dp, 12.dp, 12.dp))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                color = Color.White,
                fontSize = 15.sp
            )
        } else {
            Text(
                text = message.content,
                modifier = Modifier
                    .widthIn(max = 300.dp)
                    .border(1.dp, Color.Black, RoundedCornerShape(2.dp, 12.dp, 12.dp, 12.dp))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                color = Color.Black,
                fontSize = 15.sp
            )
        }
    }
}
