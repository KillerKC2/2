package com.killerc2.assistant

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    AssistantChat()
                }
            }
        }
    }
}

private data class ChatMessage(val fromUser: Boolean, val text: String)

@Composable
private fun AssistantChat() {
    val context = LocalContext.current
    val preferences = remember { context.getSharedPreferences("assistant", 0) }
    var endpoint by remember { mutableStateOf(preferences.getString("endpoint", "") ?: "") }
    var draft by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    val status = remember { mutableStateOf("Укажи HTTPS-адрес своего серверного API.") }
    val messages = remember { mutableStateListOf<ChatMessage>() }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) listState.animateScrollToItem(messages.lastIndex)
    }

    fun sendMessage() {
        val message = draft.trim()
        val apiUrl = endpoint.trim()
        if (busy || message.isEmpty()) return
        if (!apiUrl.startsWith("https://")) {
            status.value = "Для безопасности укажи HTTPS-адрес API."
            return
        }

        messages.add(ChatMessage(fromUser = true, text = message))
        draft = ""
        busy = true
        status.value = "Отправляю запрос…"
        preferences.edit().putString("endpoint", apiUrl).apply()

        scope.launch(Dispatchers.IO) {
            val result = runCatching { requestReply(apiUrl, message) }
            launch(Dispatchers.Main) {
                result.onSuccess { reply ->
                    messages.add(ChatMessage(fromUser = false, text = reply))
                    status.value = "Готово"
                }.onFailure { error ->
                    status.value = "Не удалось получить ответ: ${error.message ?: "ошибка сети"}"
                }
                busy = false
            }
        }
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text("Мой AI-чат", style = MaterialTheme.typography.headlineSmall)
        OutlinedTextField(
            value = endpoint,
            onValueChange = { endpoint = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("HTTPS-адрес API") },
            placeholder = { Text("https://example.com/api/chat") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done)
        )
        Text(status.value, style = MaterialTheme.typography.bodySmall)

        LazyColumn(
            modifier = Modifier.weight(1f).fillMaxWidth(),
            state = listState,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            itemsIndexed(messages) { _, message ->
                Text(
                    text = (if (message.fromUser) "Ты: " else "Ассистент: ") + message.text,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedTextField(
                value = draft,
                onValueChange = { draft = it },
                modifier = Modifier.weight(1f),
                label = { Text("Сообщение") },
                enabled = !busy,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { sendMessage() })
            )
            Button(onClick = { sendMessage() }, enabled = !busy && draft.isNotBlank()) {
                Text(if (busy) "…" else "Отправить")
            }
        }
        Spacer(modifier = Modifier.height(2.dp))
    }
}

private fun requestReply(endpoint: String, message: String): String {
    val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
        requestMethod = "POST"
        connectTimeout = 15_000
        readTimeout = 60_000
        doOutput = true
        setRequestProperty("Content-Type", "application/json; charset=utf-8")
        setRequestProperty("Accept", "application/json")
    }

    try {
        val payload = JSONObject().put("message", message).toString()
        connection.outputStream.use { it.write(payload.toByteArray(Charsets.UTF_8)) }
        val code = connection.responseCode
        val stream = if (code in 200..299) connection.inputStream else connection.errorStream
        val response = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        if (code !in 200..299) error("сервер вернул HTTP $code")
        return JSONObject(response).optString("reply").takeIf { it.isNotBlank() }
            ?: error("в ответе сервера нет поля reply")
    } finally {
        connection.disconnect()
    }
}
