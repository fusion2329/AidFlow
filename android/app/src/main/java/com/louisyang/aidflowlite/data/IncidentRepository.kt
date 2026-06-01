package com.louisyang.aidflowlite.data

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class IncidentRepository(context: Context) {
    private val databaseFile = File(context.filesDir, "aidflow-lite-incidents.json")

    suspend fun loadIncidents(): List<Incident> = withContext(Dispatchers.IO) {
        if (!databaseFile.exists()) return@withContext emptyList()

        runCatching {
            val root = JSONObject(databaseFile.readText())
            val incidents = root.optJSONArray("incidents") ?: JSONArray()
            (0 until incidents.length()).mapNotNull { index ->
                incidents.optJSONObject(index)?.toIncident()
            }
        }.getOrDefault(emptyList())
    }

    suspend fun saveIncidents(incidents: List<Incident>) = withContext(Dispatchers.IO) {
        val root = JSONObject()
            .put("schemaVersion", 1)
            .put("incidents", JSONArray(incidents.map { it.toJson() }))

        val tempFile = File(databaseFile.parentFile, "${databaseFile.name}.tmp")
        tempFile.writeText(root.toString(2))
        if (!tempFile.renameTo(databaseFile)) {
            databaseFile.writeText(root.toString(2))
            tempFile.delete()
        }
    }
}
