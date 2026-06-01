package com.louisyang.aidflowlite.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.louisyang.aidflowlite.data.CprState
import com.louisyang.aidflowlite.data.Incident
import com.louisyang.aidflowlite.data.IncidentRepository
import com.louisyang.aidflowlite.data.IncidentStatus
import com.louisyang.aidflowlite.data.TimelineCategory
import com.louisyang.aidflowlite.data.TimelineEvent
import com.louisyang.aidflowlite.notifications.CprNotificationHelper
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class AidFlowUiState(
    val incidents: List<Incident> = emptyList(),
    val currentIncident: Incident? = null,
    val cprState: CprState = CprState(),
    val currentScreen: AidFlowScreen = AidFlowScreen.Home
)

enum class AidFlowScreen {
    Home,
    Arrival,
    Cpr,
    Timeline,
    Handover,
    History
}

class AidFlowViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = IncidentRepository(application)
    private val cprNotifications = CprNotificationHelper(application)
    private val _uiState = MutableStateFlow(AidFlowUiState())
    val uiState: StateFlow<AidFlowUiState> = _uiState.asStateFlow()
    private var cprJob: Job? = null

    init {
        viewModelScope.launch {
            val loaded = repository.loadIncidents()
            _uiState.update {
                it.copy(
                    incidents = loaded,
                    currentIncident = loaded.firstOrNull { incident -> incident.status == IncidentStatus.Active }
                )
            }
        }
    }

    fun navigate(screen: AidFlowScreen) {
        _uiState.update { it.copy(currentScreen = screen) }
    }

    fun startIncident() {
        val incident = Incident(
            timeline = listOf(
                TimelineEvent(
                    title = "Arrival mode started",
                    detail = "Scene workflow opened",
                    category = TimelineCategory.Arrival
                )
            )
        )
        _uiState.update { state ->
            state.copy(
                currentIncident = incident,
                incidents = listOf(incident) + state.incidents.filterNot { it.id == incident.id },
                currentScreen = AidFlowScreen.Arrival
            )
        }
        persist()
    }

    fun completeIncident() {
        val current = _uiState.value.currentIncident ?: return
        val completed = current.copy(
            status = IncidentStatus.Completed,
            timeline = current.timeline + TimelineEvent(
                title = "Incident completed",
                category = TimelineCategory.Observation
            )
        )
        _uiState.update { state ->
            state.copy(
                currentIncident = null,
                incidents = state.incidents.replaceIncident(completed),
                currentScreen = AidFlowScreen.Home
            )
        }
        persist()
    }

    fun recordArrivalAction(title: String, category: TimelineCategory) {
        appendTimeline(TimelineEvent(title = title, category = category))
    }

    fun addQuickObservation(text: String) {
        val clean = text.trim()
        if (clean.isBlank()) return
        appendTimeline(TimelineEvent(title = clean, category = TimelineCategory.Observation))
    }

    fun toggleCpr() {
        val next = _uiState.value.cprState.copy(isRunning = !_uiState.value.cprState.isRunning)
        setCprState(next)
        if (next.isRunning) startCprTicker() else cprJob?.cancel()
    }

    fun resetCpr() {
        cprJob?.cancel()
        setCprState(CprState())
        cprNotifications.clear()
    }

    private fun startCprTicker() {
        cprJob?.cancel()
        cprJob = viewModelScope.launch {
            while (true) {
                delay(if (_uiState.value.cprState.isBreathPhase) 1000 else 545)
                tickCpr()
            }
        }
    }

    private fun tickCpr() {
        val current = _uiState.value.cprState
        if (!current.isRunning) return

        val next = if (current.isBreathPhase) {
            if (current.breathSecondsRemaining <= 1) {
                current.copy(
                    compressionCount = 0,
                    cycleCount = current.cycleCount + 1,
                    isBreathPhase = false,
                    breathSecondsRemaining = 5
                )
            } else {
                current.copy(breathSecondsRemaining = current.breathSecondsRemaining - 1)
            }
        } else {
            if (current.compressionCount >= 29) {
                current.copy(
                    compressionCount = 30,
                    isBreathPhase = true,
                    breathSecondsRemaining = 5
                )
            } else {
                current.copy(compressionCount = current.compressionCount + 1)
            }
        }

        setCprState(next)
    }

    private fun setCprState(state: CprState) {
        _uiState.update { it.copy(cprState = state) }
        if (state.isRunning || state.compressionCount > 0 || state.cycleCount > 0) {
            cprNotifications.update(state)
        }
    }

    private fun appendTimeline(event: TimelineEvent) {
        val current = _uiState.value.currentIncident ?: return
        val updated = current.copy(timeline = listOf(event) + current.timeline)
        _uiState.update { state ->
            state.copy(
                currentIncident = updated,
                incidents = state.incidents.replaceIncident(updated)
            )
        }
        persist()
    }

    private fun persist() {
        val incidents = _uiState.value.incidents
        viewModelScope.launch {
            repository.saveIncidents(incidents)
        }
    }
}

private fun List<Incident>.replaceIncident(updated: Incident): List<Incident> {
    val replaced = map { if (it.id == updated.id) updated else it }
    return if (any { it.id == updated.id }) replaced else listOf(updated) + this
}
