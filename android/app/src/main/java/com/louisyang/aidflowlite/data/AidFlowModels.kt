package com.louisyang.aidflowlite.data

import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.util.UUID

enum class IncidentStatus { Active, Completed }

enum class TimelineCategory {
    Arrival,
    Safety,
    Assessment,
    Escalation,
    Treatment,
    Observation
}

data class PatientProfile(
    val fullName: String = "",
    val age: String = "",
    val sex: String = "",
    val allergies: String = "",
    val medications: String = "",
    val treatment: String = "",
    val medicalHistory: String = "",
    val lastOralIntake: String = "",
    val eventsBefore: String = ""
)

data class VitalSignsRecord(
    val id: String = UUID.randomUUID().toString(),
    val recordedAt: String = Instant.now().toString(),
    val heartRate: String = "",
    val respiratoryRate: String = "",
    val oxygenSaturation: String = "",
    val bloodPressure: String = "",
    val painScore: String = "",
    val avpu: String = "",
    val notes: String = ""
)

data class TimelineEvent(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: String = Instant.now().toString(),
    val title: String,
    val detail: String? = null,
    val category: TimelineCategory = TimelineCategory.Observation
)

data class Incident(
    val id: String = UUID.randomUUID().toString(),
    val startedAt: String = Instant.now().toString(),
    val status: IncidentStatus = IncidentStatus.Active,
    val patientProfile: PatientProfile = PatientProfile(),
    val patientNotes: String = "",
    val vitalSigns: List<VitalSignsRecord> = emptyList(),
    val timeline: List<TimelineEvent> = emptyList(),
    val arrivalStepIndex: Int = 0
)

data class CprState(
    val isRunning: Boolean = false,
    val compressionCount: Int = 0,
    val cycleCount: Int = 0,
    val isBreathPhase: Boolean = false,
    val breathSecondsRemaining: Int = 5
) {
    val phaseLabel: String
        get() = if (isBreathPhase) "Give 2 breaths" else "Compressions"
}

fun Incident.toJson(): JSONObject = JSONObject()
    .put("id", id)
    .put("startedAt", startedAt)
    .put("status", status.name)
    .put("patientProfile", patientProfile.toJson())
    .put("patientNotes", patientNotes)
    .put("vitalSigns", JSONArray(vitalSigns.map { it.toJson() }))
    .put("timeline", JSONArray(timeline.map { it.toJson() }))
    .put("arrivalStepIndex", arrivalStepIndex)

fun PatientProfile.toJson(): JSONObject = JSONObject()
    .put("fullName", fullName)
    .put("age", age)
    .put("sex", sex)
    .put("allergies", allergies)
    .put("medications", medications)
    .put("treatment", treatment)
    .put("medicalHistory", medicalHistory)
    .put("lastOralIntake", lastOralIntake)
    .put("eventsBefore", eventsBefore)

fun VitalSignsRecord.toJson(): JSONObject = JSONObject()
    .put("id", id)
    .put("recordedAt", recordedAt)
    .put("heartRate", heartRate)
    .put("respiratoryRate", respiratoryRate)
    .put("oxygenSaturation", oxygenSaturation)
    .put("bloodPressure", bloodPressure)
    .put("painScore", painScore)
    .put("avpu", avpu)
    .put("notes", notes)

fun TimelineEvent.toJson(): JSONObject = JSONObject()
    .put("id", id)
    .put("timestamp", timestamp)
    .put("title", title)
    .put("detail", detail)
    .put("category", category.name)

fun JSONObject.toIncident(): Incident = Incident(
    id = optString("id", UUID.randomUUID().toString()),
    startedAt = optString("startedAt", Instant.now().toString()),
    status = enumValueOrDefault(optString("status"), IncidentStatus.Active),
    patientProfile = optJSONObject("patientProfile")?.toPatientProfile() ?: PatientProfile(),
    patientNotes = optString("patientNotes", ""),
    vitalSigns = optJSONArray("vitalSigns").toVitalSignsList(),
    timeline = optJSONArray("timeline").toTimelineList(),
    arrivalStepIndex = optInt("arrivalStepIndex", 0)
)

fun JSONObject.toPatientProfile(): PatientProfile = PatientProfile(
    fullName = optString("fullName", ""),
    age = optString("age", ""),
    sex = optString("sex", ""),
    allergies = optString("allergies", ""),
    medications = optString("medications", ""),
    treatment = optString("treatment", ""),
    medicalHistory = optString("medicalHistory", ""),
    lastOralIntake = optString("lastOralIntake", ""),
    eventsBefore = optString("eventsBefore", "")
)

fun JSONObject.toVitalSignsRecord(): VitalSignsRecord = VitalSignsRecord(
    id = optString("id", UUID.randomUUID().toString()),
    recordedAt = optString("recordedAt", Instant.now().toString()),
    heartRate = optString("heartRate", ""),
    respiratoryRate = optString("respiratoryRate", ""),
    oxygenSaturation = optString("oxygenSaturation", ""),
    bloodPressure = optString("bloodPressure", ""),
    painScore = optString("painScore", ""),
    avpu = optString("avpu", ""),
    notes = optString("notes", "")
)

fun JSONObject.toTimelineEvent(): TimelineEvent = TimelineEvent(
    id = optString("id", UUID.randomUUID().toString()),
    timestamp = optString("timestamp", Instant.now().toString()),
    title = optString("title", "Observation"),
    detail = optString("detail", "").ifBlank { null },
    category = enumValueOrDefault(optString("category"), TimelineCategory.Observation)
)

private fun JSONArray?.toVitalSignsList(): List<VitalSignsRecord> {
    if (this == null) return emptyList()
    return (0 until length()).mapNotNull { index ->
        optJSONObject(index)?.toVitalSignsRecord()
    }
}

private fun JSONArray?.toTimelineList(): List<TimelineEvent> {
    if (this == null) return emptyList()
    return (0 until length()).mapNotNull { index ->
        optJSONObject(index)?.toTimelineEvent()
    }
}

private inline fun <reified T : Enum<T>> enumValueOrDefault(rawValue: String?, default: T): T =
    runCatching { enumValueOf<T>(rawValue.orEmpty()) }.getOrDefault(default)
