package com.killerc2.assistant

import android.content.Context
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    TodoScreen()
                }
            }
        }
    }
}

private data class TodoTask(
    val id: Long,
    val title: String,
    val completed: Boolean = false
)

private enum class TaskFilter(val label: String) {
    All("Все"), Active("Текущие"), Completed("Готово")
}

@Composable
private fun TodoScreen() {
    val context = LocalContext.current
    val preferences = remember { context.getSharedPreferences("todo_storage", Context.MODE_PRIVATE) }
    val tasks = remember {
        mutableStateListOf<TodoTask>().apply { addAll(readTasks(preferences.getString("tasks", "[]") ?: "[]")) }
    }
    var draft by remember { mutableStateOf("") }
    var filter by remember { mutableStateOf(TaskFilter.All) }

    fun persist() {
        preferences.edit().putString("tasks", writeTasks(tasks)).apply()
    }

    fun addTask() {
        val title = draft.trim()
        if (title.isEmpty()) return
        tasks.add(0, TodoTask(id = System.currentTimeMillis(), title = title))
        draft = ""
        persist()
    }

    val visibleTasks = when (filter) {
        TaskFilter.All -> tasks
        TaskFilter.Active -> tasks.filterNot { it.completed }
        TaskFilter.Completed -> tasks.filter { it.completed }
    }
    val doneCount = tasks.count { it.completed }

    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text("Мои дела", style = MaterialTheme.typography.headlineLarge)
        Text(
            if (tasks.isEmpty()) "Добавь первое дело — список сохранится на этом устройстве."
            else "Выполнено $doneCount из ${tasks.size}",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = draft,
                onValueChange = { draft = it },
                modifier = Modifier.weight(1f),
                label = { Text("Новое дело") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { addTask() })
            )
            Spacer(Modifier.width(8.dp))
            Button(onClick = { addTask() }, enabled = draft.isNotBlank()) { Text("Добавить") }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TaskFilter.values().forEach { option ->
                FilterChip(
                    selected = filter == option,
                    onClick = { filter = option },
                    label = { Text(option.label) }
                )
            }
        }

        if (tasks.isEmpty()) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Text(
                    "Пока здесь пусто. Запиши дело выше.",
                    modifier = Modifier.padding(20.dp),
                    style = MaterialTheme.typography.bodyLarge
                )
            }
        } else if (visibleTasks.isEmpty()) {
            Text("В этом разделе пока нет дел.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f).fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(visibleTasks, key = { it.id }) { task ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(start = 8.dp, end = 12.dp, top = 4.dp, bottom = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Checkbox(
                                checked = task.completed,
                                onCheckedChange = { checked ->
                                    val index = tasks.indexOfFirst { it.id == task.id }
                                    if (index >= 0) {
                                        tasks[index] = tasks[index].copy(completed = checked)
                                        persist()
                                    }
                                }
                            )
                            Text(
                                task.title,
                                modifier = Modifier.weight(1f),
                                style = MaterialTheme.typography.bodyLarge,
                                textDecoration = if (task.completed) TextDecoration.LineThrough else TextDecoration.None,
                                color = if (task.completed) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface
                            )
                            TextButton(onClick = {
                                tasks.removeAll { it.id == task.id }
                                persist()
                            }) { Text("Удалить") }
                        }
                    }
                }
            }
        }

        if (tasks.any { it.completed }) {
            Spacer(Modifier.height(2.dp))
            TextButton(onClick = {
                tasks.removeAll { it.completed }
                persist()
            }) { Text("Удалить выполненные") }
        }
    }
}

private fun readTasks(raw: String): List<TodoTask> = runCatching {
    val array = JSONArray(raw)
    (0 until array.length()).mapNotNull { index ->
        val item = array.optJSONObject(index) ?: return@mapNotNull null
        val title = item.optString("title").trim()
        if (title.isEmpty()) null else TodoTask(
            id = item.optLong("id", index.toLong()),
            title = title,
            completed = item.optBoolean("completed", false)
        )
    }
}.getOrDefault(emptyList())

private fun writeTasks(tasks: List<TodoTask>): String {
    val array = JSONArray()
    tasks.forEach { task ->
        array.put(JSONObject().apply {
            put("id", task.id)
            put("title", task.title)
            put("completed", task.completed)
        })
    }
    return array.toString()
}
