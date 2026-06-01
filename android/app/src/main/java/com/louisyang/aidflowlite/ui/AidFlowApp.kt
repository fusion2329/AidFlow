package com.louisyang.aidflowlite.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.louisyang.aidflowlite.data.Incident
import com.louisyang.aidflowlite.data.TimelineCategory
import com.louisyang.aidflowlite.data.TimelineEvent

private val AidDark = Color(0xFF071012)
private val AidPanel = Color(0xFF101C1E)
private val AidPanelAlt = Color(0xFF172628)
private val AidAccent = Color(0xFF2DBAA2)
private val AidWarning = Color(0xFFF6D36B)
private val AidDanger = Color(0xFFFF6B5F)
private val AidMuted = Color(0xFFA8B7B5)

@Composable
fun AidFlowApp(viewModel: AidFlowViewModel) {
    val state by viewModel.uiState.collectAsState()

    MaterialTheme(
        colorScheme = darkColorScheme(
            background = AidDark,
            surface = AidPanel,
            primary = AidAccent,
            secondary = AidWarning,
            error = AidDanger
        )
    ) {
        Scaffold(
            containerColor = AidDark,
            bottomBar = {
                NavigationBar(containerColor = AidPanel) {
                    NavigationBarItem(
                        selected = state.currentScreen == AidFlowScreen.Home,
                        onClick = { viewModel.navigate(AidFlowScreen.Home) },
                        icon = { Icon(Icons.Default.Home, contentDescription = null) },
                        label = { Text("Home") }
                    )
                    NavigationBarItem(
                        selected = state.currentScreen == AidFlowScreen.Cpr,
                        onClick = { viewModel.navigate(AidFlowScreen.Cpr) },
                        icon = { Icon(Icons.Default.Favorite, contentDescription = null) },
                        label = { Text("CPR") }
                    )
                    NavigationBarItem(
                        selected = state.currentScreen == AidFlowScreen.Timeline,
                        onClick = { viewModel.navigate(AidFlowScreen.Timeline) },
                        icon = { Icon(Icons.Default.MedicalServices, contentDescription = null) },
                        label = { Text("Timeline") }
                    )
                    NavigationBarItem(
                        selected = state.currentScreen == AidFlowScreen.History,
                        onClick = { viewModel.navigate(AidFlowScreen.History) },
                        icon = { Icon(Icons.Default.History, contentDescription = null) },
                        label = { Text("History") }
                    )
                }
            }
        ) { padding ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(AidDark)
                    .padding(padding)
                    .padding(16.dp)
            ) {
                when (state.currentScreen) {
                    AidFlowScreen.Home -> HomeScreen(
                        activeIncident = state.currentIncident,
                        onStart = viewModel::startIncident,
                        onResume = { viewModel.navigate(AidFlowScreen.Arrival) },
                        onHistory = { viewModel.navigate(AidFlowScreen.History) }
                    )
                    AidFlowScreen.Arrival -> ArrivalScreen(
                        incident = state.currentIncident,
                        onRecord = viewModel::recordArrivalAction,
                        onCpr = { viewModel.navigate(AidFlowScreen.Cpr) },
                        onHandover = { viewModel.navigate(AidFlowScreen.Handover) },
                        onComplete = viewModel::completeIncident
                    )
                    AidFlowScreen.Cpr -> CprScreen(
                        state = state.cprState,
                        onToggle = viewModel::toggleCpr,
                        onReset = viewModel::resetCpr
                    )
                    AidFlowScreen.Timeline -> TimelineScreen(
                        incident = state.currentIncident,
                        onAdd = viewModel::addQuickObservation
                    )
                    AidFlowScreen.Handover -> HandoverScreen(incident = state.currentIncident)
                    AidFlowScreen.History -> HistoryScreen(incidents = state.incidents)
                }
            }
        }
    }
}

@Composable
private fun HomeScreen(
    activeIncident: Incident?,
    onStart: () -> Unit,
    onResume: () -> Unit,
    onHistory: () -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        ScreenTitle("AidFlow", "Lite Android field workflow")
        StatusCard(
            title = if (activeIncident == null) "Ready" else "Incident active",
            detail = if (activeIncident == null) "Start arrival mode" else "${activeIncident.timeline.size} timeline events",
            color = if (activeIncident == null) AidAccent else AidWarning
        )
        Button(
            onClick = if (activeIncident == null) onStart else onResume,
            modifier = Modifier
                .fillMaxWidth()
                .height(72.dp),
            colors = ButtonDefaults.buttonColors(containerColor = AidAccent)
        ) {
            Icon(Icons.Default.PlayArrow, contentDescription = null)
            Text(
                text = if (activeIncident == null) "START ARRIVAL" else "RESUME",
                modifier = Modifier.padding(start = 10.dp),
                fontWeight = FontWeight.Bold
            )
        }
        TextButton(onClick = onHistory, modifier = Modifier.fillMaxWidth()) {
            Text("Past incidents")
        }
    }
}

@Composable
private fun ArrivalScreen(
    incident: Incident?,
    onRecord: (String, TimelineCategory) -> Unit,
    onCpr: () -> Unit,
    onHandover: () -> Unit,
    onComplete: () -> Unit
) {
    if (incident == null) {
        EmptyState("No active incident")
        return
    }

    val actions = listOf(
        Triple("DANGER", "Scene safe / hazards checked", TimelineCategory.Safety),
        Triple("RESPONSE", "Response checked", TimelineCategory.Assessment),
        Triple("SEND", "Help / 000 considered", TimelineCategory.Escalation),
        Triple("AIRWAY", "Airway checked", TimelineCategory.Assessment),
        Triple("BREATHING", "Breathing checked", TimelineCategory.Assessment),
        Triple("AED", "AED requested / applied", TimelineCategory.Treatment)
    )

    LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { ScreenTitle("Arrival", "Cockpit checklist") }
        items(actions) { action ->
            ActionRow(
                label = action.first,
                detail = action.second,
                onClick = { onRecord(action.second, action.third) }
            )
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = onCpr,
                    modifier = Modifier
                        .weight(1f)
                        .height(58.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AidDanger)
                ) {
                    Text("CPR", fontWeight = FontWeight.Bold)
                }
                Button(
                    onClick = onHandover,
                    modifier = Modifier
                        .weight(1f)
                        .height(58.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AidPanelAlt)
                ) {
                    Text("HANDOVER", fontWeight = FontWeight.Bold)
                }
            }
        }
        item {
            TextButton(onClick = onComplete, modifier = Modifier.fillMaxWidth()) {
                Text("Complete incident")
            }
        }
    }
}

@Composable
private fun CprScreen(
    state: com.louisyang.aidflowlite.data.CprState,
    onToggle: () -> Unit,
    onReset: () -> Unit
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        ScreenTitle(state.phaseLabel, if (state.isBreathPhase) "Resume after prompt" else "110/min rhythm")
        Box(
            modifier = Modifier
                .size(250.dp)
                .clip(CircleShape)
                .background(if (state.isBreathPhase) AidDanger.copy(alpha = 0.22f) else AidAccent.copy(alpha = 0.18f)),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = if (state.isBreathPhase) "${state.breathSecondsRemaining}" else "${state.compressionCount}",
                    fontSize = 82.sp,
                    fontWeight = FontWeight.Black,
                    color = Color.White
                )
                Text(
                    text = if (state.isBreathPhase) "seconds" else "of 30",
                    color = if (state.isBreathPhase) AidDanger else AidAccent,
                    fontWeight = FontWeight.Bold
                )
            }
        }
        LinearProgressIndicator(
            progress = { if (state.isBreathPhase) 1f else state.compressionCount / 30f },
            modifier = Modifier.fillMaxWidth(),
            color = if (state.isBreathPhase) AidDanger else AidAccent,
            trackColor = AidPanelAlt
        )
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Metric("Rate", "110/min")
            Metric("Cycles", "${state.cycleCount}")
            Metric("Breaths", "2")
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(
                onClick = onToggle,
                modifier = Modifier
                    .weight(1f)
                    .height(60.dp),
                colors = ButtonDefaults.buttonColors(containerColor = if (state.isRunning) AidWarning else AidAccent)
            ) {
                Icon(if (state.isRunning) Icons.Default.Stop else Icons.Default.PlayArrow, contentDescription = null)
                Text(if (state.isRunning) "PAUSE" else "START", modifier = Modifier.padding(start = 8.dp), fontWeight = FontWeight.Bold)
            }
            IconButton(
                onClick = onReset,
                modifier = Modifier
                    .size(60.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(AidPanelAlt)
            ) {
                Icon(Icons.Default.Refresh, contentDescription = "Reset", tint = Color.White)
            }
        }
        WarningStrip("Training aid only. Follow local protocol.")
    }
}

@Composable
private fun TimelineScreen(incident: Incident?, onAdd: (String) -> Unit) {
    var note by remember { mutableStateOf("") }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        ScreenTitle("Timeline", "Fast event log")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextField(
                value = note,
                onValueChange = { note = it },
                modifier = Modifier.weight(1f),
                placeholder = { Text("Observation") },
                singleLine = true
            )
            Button(
                onClick = {
                    onAdd(note)
                    note = ""
                },
                modifier = Modifier.height(56.dp)
            ) {
                Icon(Icons.Default.Check, contentDescription = null)
            }
        }
        EventList(
            events = incident?.timeline.orEmpty(),
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun HandoverScreen(incident: Incident?) {
    if (incident == null) {
        EmptyState("No active incident")
        return
    }

    LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { ScreenTitle("Handover", "Read out summary") }
        item { HandoverLine("Started", incident.startedAt) }
        item { HandoverLine("Patient", incident.patientProfile.fullName.ifBlank { "Unknown" }) }
        item { HandoverLine("Notes", incident.patientNotes.ifBlank { "None recorded" }) }
        item { HandoverLine("Timeline", "${incident.timeline.size} events") }
        items(incident.timeline.take(8)) { event ->
            EventCard(event)
        }
    }
}

@Composable
private fun HistoryScreen(incidents: List<Incident>) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { ScreenTitle("History", "${incidents.size} local incidents") }
        if (incidents.isEmpty()) {
            item { EmptyState("No saved incidents") }
        } else {
            items(incidents) { incident ->
                StatusCard(
                    title = incident.status.name,
                    detail = "${incident.startedAt} | ${incident.timeline.size} events",
                    color = if (incident.status.name == "Active") AidWarning else AidAccent
                )
            }
        }
    }
}

@Composable
private fun ScreenTitle(title: String, subtitle: String) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(title, fontSize = 34.sp, fontWeight = FontWeight.Black, color = Color.White)
        Text(subtitle, color = AidMuted, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun StatusCard(title: String, detail: String, color: Color) {
    Card(colors = CardDefaults.cardColors(containerColor = AidPanel), shape = RoundedCornerShape(8.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(14.dp)
                    .clip(CircleShape)
                    .background(color)
            )
            Column(modifier = Modifier.padding(start = 12.dp)) {
                Text(title, color = Color.White, fontWeight = FontWeight.Bold)
                Text(detail, color = AidMuted, maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

@Composable
private fun ActionRow(label: String, detail: String, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(64.dp),
        colors = ButtonDefaults.buttonColors(containerColor = AidPanel)
    ) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(label, color = AidAccent, fontWeight = FontWeight.Black, modifier = Modifier.weight(0.34f))
            Text(detail, color = Color.White, fontWeight = FontWeight.Bold, modifier = Modifier.weight(0.66f))
        }
    }
}

@Composable
private fun RowScope.Metric(title: String, value: String) {
    Card(
        modifier = Modifier.weight(1f),
        colors = CardDefaults.cardColors(containerColor = AidPanel),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(value, color = Color.White, fontWeight = FontWeight.Black)
            Text(title, color = AidMuted, fontSize = 12.sp)
        }
    }
}

@Composable
private fun WarningStrip(text: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(AidWarning.copy(alpha = 0.12f))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Default.Warning, contentDescription = null, tint = AidWarning)
        Text(text, color = AidWarning, modifier = Modifier.padding(start = 8.dp), fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun EventList(events: List<TimelineEvent>, modifier: Modifier = Modifier) {
    LazyColumn(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (events.isEmpty()) {
            item { EmptyState("No events yet") }
        } else {
            items(events) { event ->
                EventCard(event)
            }
        }
    }
}

@Composable
private fun EventCard(event: TimelineEvent) {
    Card(colors = CardDefaults.cardColors(containerColor = AidPanel), shape = RoundedCornerShape(8.dp)) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(event.title, color = Color.White, fontWeight = FontWeight.Bold)
            if (!event.detail.isNullOrBlank()) {
                Text(event.detail, color = AidMuted)
            }
            Text(event.category.name, color = AidAccent, fontSize = 12.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun HandoverLine(label: String, value: String) {
    Card(colors = CardDefaults.cardColors(containerColor = AidPanelAlt), shape = RoundedCornerShape(8.dp)) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(label, color = AidMuted, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            Text(value, color = Color.White, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun EmptyState(text: String) {
    Surface(
        color = AidPanel,
        shape = RoundedCornerShape(8.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Text(text, color = AidMuted, modifier = Modifier.padding(18.dp), fontWeight = FontWeight.Bold)
    }
}
