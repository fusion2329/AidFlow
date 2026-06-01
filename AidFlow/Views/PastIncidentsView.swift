import EventKit
import MapKit
import PhotosUI
import SwiftUI

struct PastIncidentsView: View {
    @EnvironmentObject private var incidentStore: IncidentStore
    private let calendarSync = CalendarEventSync()
    @State private var isSelecting = false
    @State private var selectedIncidentIDs: Set<UUID> = []
    @State private var selectedShareURL: URL?
    @State private var showingDeleteConfirmation = false
    @State private var showingPlanEventSheet = false

    private var incidents: [Incident] {
        incidentStore.incidentHistory()
    }

    private var upcomingEvents: [PlannedEvent] {
        incidentStore.upcomingPlannedEvents()
    }

    private var pastEvents: [PlannedEvent] {
        incidentStore.pastPlannedEvents()
    }

    private var selectedIncidents: [Incident] {
        incidents.filter { selectedIncidentIDs.contains($0.id) }
    }

    private var hasRoutineItems: Bool {
        !upcomingEvents.isEmpty || !incidents.isEmpty || !pastEvents.isEmpty
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            if !hasRoutineItems {
                SceneEmptyState(
                    title: "No routine yet".afLocalized,
                    systemImage: "calendar"
                )
                .padding(24)
            } else {
                List {
                    if !upcomingEvents.isEmpty {
                        Section {
                            ForEach(upcomingEvents) { event in
                                plannedEventNavigationRow(event: event, isPast: false)
                            }
                        } header: {
                            routineSectionTitle("Upcoming Events".afLocalized)
                        }
                    }

                    if !incidents.isEmpty {
                        Section {
                            ForEach(incidents) { incident in
                                incidentNavigationRow(incident)
                            }
                        } header: {
                            routineSectionTitle("Past Records".afLocalized)
                        }
                    }

                    if !pastEvents.isEmpty {
                        Section {
                            ForEach(pastEvents) { event in
                                plannedEventNavigationRow(event: event, isPast: true)
                            }
                        } header: {
                            routineSectionTitle("Completed Events".afLocalized)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .developerScreenID("310001", "PastIncidentsView")
        .navigationTitle("Routine".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showingPlanEventSheet) {
            NavigationStack {
                PlannedEventEditorView()
            }
        }
        .toolbar {
            if !isSelecting {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingPlanEventSheet = true
                    } label: {
                        Label("Plan Event".afLocalized, systemImage: "calendar.badge.plus")
                    }
                }
            }

            if !incidents.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button((isSelecting ? "Done" : "Select").afLocalized) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isSelecting {
                                selectedIncidentIDs.removeAll()
                            }
                            isSelecting.toggle()
                        }
                    }
                }
            }

            if isSelecting {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 26) {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash.fill")
                                .frame(width: 34, height: 34)
                        }
                        .disabled(selectedIncidentIDs.isEmpty)

                        if let selectedShareURL {
                            ShareLink(item: selectedShareURL) {
                                Image(systemName: "square.and.arrow.up")
                                    .frame(width: 34, height: 34)
                            }
                            .disabled(selectedIncidentIDs.isEmpty)
                        }
                    }
                }
            }
        }
        .alert("Delete selected incidents?".afLocalized, isPresented: $showingDeleteConfirmation) {
            Button("Delete".afLocalized, role: .destructive) {
                incidentStore.deleteIncidents(ids: selectedIncidentIDs)
                selectedIncidentIDs.removeAll()
                isSelecting = false
            }

            Button("Cancel".afLocalized, role: .cancel) {}
        } message: {
            Text("This removes selected incident and handover history from this device.".afLocalized)
        }
        .onChange(of: selectedIncidentIDs) { _ in
            refreshSelectedShareURL()
        }
    }

    private func refreshSelectedShareURL() {
        selectedShareURL = incidentStore.selectedIncidentsDocumentURL(for: selectedIncidents)
    }

    private func toggleSelection(for incident: Incident) {
        if selectedIncidentIDs.contains(incident.id) {
            selectedIncidentIDs.remove(incident.id)
        } else {
            selectedIncidentIDs.insert(incident.id)
        }
    }

    private func plannedEventNavigationRow(event: PlannedEvent, isPast: Bool) -> some View {
        NavigationLink {
            PlannedEventDetailView(event: event)
        } label: {
            PlannedEventRow(event: event, isPast: isPast)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deletePlannedEvent(event)
            } label: {
                Label("Delete".afLocalized, systemImage: "trash.fill")
            }
        }
    }

    private func incidentNavigationRow(_ incident: Incident) -> some View {
        Group {
            if isSelecting {
                HStack(spacing: 10) {
                    Image(systemName: selectedIncidentIDs.contains(incident.id) ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(selectedIncidentIDs.contains(incident.id) ? Color.sceneAccent : Color.sceneMuted)
                        .frame(width: 34, height: 44)
                        .accessibilityLabel("Select incident".afLocalized)

                    HistoryIncidentRow(incident: incident)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleSelection(for: incident)
                }
            } else {
                NavigationLink {
                    IncidentHistoryDetailView(incident: incident)
                } label: {
                    HistoryIncidentRow(incident: incident)
                }
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                incidentStore.deleteIncident(id: incident.id)
                selectedIncidentIDs.remove(incident.id)
            } label: {
                Label("Delete".afLocalized, systemImage: "trash.fill")
            }
        }
    }

    private func deletePlannedEvent(_ event: PlannedEvent) {
        Task {
            await calendarSync.deleteCalendarEvent(identifier: event.calendarEventIdentifier)
            await MainActor.run {
                incidentStore.deletePlannedEvent(id: event.id)
            }
        }
    }

    private func routineSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.sceneAccent)
            .textCase(.uppercase)
            .padding(.horizontal, 2)
    }
}

private struct PlannedEventRow: View {
    let event: PlannedEvent
    let isPast: Bool

    var body: some View {
        HStack(spacing: 12) {
            eventThumbnail

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(event.name.isEmpty ? "Untitled event".afLocalized : event.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text((isPast ? "Completed" : "Planned").afLocalized)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background((isPast ? Color.sceneMuted : Color.sceneAccent), in: Capsule())
                }

                Text(event.timeSummary)
                    .font(.subheadline)
                    .foregroundStyle(Color.sceneMuted)
                    .lineLimit(1)

                if !event.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(event.location)
                        .font(.caption)
                        .foregroundStyle(Color.sceneMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            dateBadge
        }
        .padding(14)
        .liquidGlass(tint: isPast ? Color.sceneMuted : Color.sceneAccent, opacity: isPast ? 0.07 : 0.10)
        .frame(maxWidth: .infinity)
    }

    private var eventThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.sceneAccent.opacity(isPast ? 0.10 : 0.16))

            if let imageData = event.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: isPast ? "calendar.badge.checkmark" : "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(isPast ? Color.sceneMuted : Color.sceneAccent)
            }
        }
        .frame(width: 42, height: 42)
        .clipped()
    }

    private var dateBadge: some View {
        VStack(spacing: 2) {
            Text(DateFormatter.eventDay.string(from: event.startsAt))
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)

            Text(DateFormatter.eventMonth.string(from: event.startsAt).uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(isPast ? Color.sceneMuted : Color.sceneAccent)
        }
        .frame(width: 48, height: 52)
        .liquidGlass(tint: isPast ? Color.sceneMuted : Color.sceneAccent, opacity: 0.08)
    }
}

private struct PlannedEventDetailView: View {
    @EnvironmentObject private var incidentStore: IncidentStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("routine.travelMode") private var travelMode = EventTravelMode.driving.rawValue
    @StateObject private var locationManager = LocationManager()
    private let calendarSync = CalendarEventSync()
    let event: PlannedEvent
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var travelSummary = ""
    @State private var isCalculatingTravel = false
    @State private var canNavigateToEvent = false

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    travelPanel
                    actionPanel
                    notesPanel
                }
                .padding(16)
            }
        }
        .developerScreenID("320001", "PlannedEventDetailView")
        .navigationTitle("Planned Event".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                PlannedEventEditorView(editingEvent: event)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit".afLocalized) {
                    showingEditSheet = true
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .alert("Delete planned event?".afLocalized, isPresented: $showingDeleteConfirmation) {
            Button("Delete".afLocalized, role: .destructive) {
                Task {
                    await calendarSync.deleteCalendarEvent(identifier: event.calendarEventIdentifier)
                    await MainActor.run {
                        incidentStore.deletePlannedEvent(id: event.id)
                        dismiss()
                    }
                }
            }
            Button("Cancel".afLocalized, role: .cancel) {}
        } message: {
            Text("This removes the planned event from Routine.".afLocalized)
        }
        .onReceive(locationManager.$snapshot) { snapshot in
            guard let snapshot else { return }
            calculateTravelTime(from: snapshot)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageData = event.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(event.isUpcoming ? "UPCOMING".afLocalized : "COMPLETED".afLocalized)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.sceneAccent)

                Text(event.name.isEmpty ? "Untitled event".afLocalized : event.name)
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Label(event.timeSummary, systemImage: "clock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)

                if !event.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.sceneMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.12)
    }

    private var travelPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Travel time".afLocalized)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.sceneAccent)
                    .textCase(.uppercase)

                Spacer()

                Label(AppStrings.display(travelMode), systemImage: travelModeIcon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.sceneMuted)
            }

            if event.hasResolvedLocation {
                Text(travelSummary.isEmpty ? "Calculate time from your current location.".afLocalized : travelSummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Button {
                    isCalculatingTravel = true
                    canNavigateToEvent = false
                    travelSummary = "Getting current location...".afLocalized
                    locationManager.requestLocation()
                } label: {
                    Label(isCalculatingTravel ? "Calculating...".afLocalized : "Calculate travel time".afLocalized, systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SceneSecondaryButtonStyle())
                .disabled(isCalculatingTravel)

                if canNavigateToEvent {
                    Button {
                        openNavigation()
                    } label: {
                        Label("Navigate".afLocalized, systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ScenePrimaryButtonStyle())
                }
            } else {
                Text("Select a suggested map address first to calculate travel time.".afLocalized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
            }
        }
        .historyCard()
    }

    private var travelModeIcon: String {
        (EventTravelMode(rawValue: travelMode) ?? .driving).systemImage
    }

    private func calculateTravelTime(from snapshot: IncidentLocation) {
        guard let latitude = event.locationLatitude, let longitude = event.locationLongitude else {
            travelSummary = "Location coordinates not available.".afLocalized
            isCalculatingTravel = false
            canNavigateToEvent = false
            return
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: snapshot.latitude, longitude: snapshot.longitude)))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
        request.transportType = transportType

        Task {
            let response = try? await MKDirections(request: request).calculate()
            let route = response?.routes.first
            await MainActor.run {
                if let route {
                    let minutes = max(1, Int((route.expectedTravelTime / 60).rounded()))
                    travelSummary = AppStrings.text("About %d min via %@", minutes, AppStrings.display(travelMode))
                    canNavigateToEvent = true
                } else {
                    travelSummary = "Travel time unavailable.".afLocalized
                    canNavigateToEvent = false
                }
                isCalculatingTravel = false
            }
        }
    }

    private func openNavigation() {
        guard let latitude = event.locationLatitude, let longitude = event.locationLongitude else { return }
        let encodedName = (event.location.isEmpty ? event.name : event.location)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let flag = (EventTravelMode(rawValue: travelMode) ?? .driving) == .driving ? "d" : "r"
        if let url = URL(string: "http://maps.apple.com/?daddr=\(latitude),\(longitude)&q=\(encodedName)&dirflg=\(flag)") {
            openURL(url)
        }
    }

    private var transportType: MKDirectionsTransportType {
        switch EventTravelMode(rawValue: travelMode) ?? .driving {
        case .driving:
            return .automobile
        case .publicTransport:
            return .transit
        }
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Use this event".afLocalized)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .textCase(.uppercase)

            NavigationLink {
                ArrivalModeView()
                    .onAppear {
                        if incidentStore.currentIncident == nil {
                            incidentStore.startIncident(plannedEvent: event)
                        } else {
                            incidentStore.applyPlannedEventToCurrentIncident(event)
                        }
                    }
            } label: {
                Label("Start Arrival Mode with this event".afLocalized, systemImage: "cross.case.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScenePrimaryButtonStyle())

            NavigationLink {
                PatientRecordFormView(plannedEvent: event)
            } label: {
                Label("Open Patient Record with this event".afLocalized, systemImage: "doc.text.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SceneSecondaryButtonStyle())
        }
        .historyCard()
    }

    private var notesPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes".afLocalized)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .textCase(.uppercase)

            Text(event.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No notes recorded.".afLocalized : event.notes)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .historyCard()
    }
}

private struct PlannedEventEditorView: View {
    @EnvironmentObject private var incidentStore: IncidentStore
    @Environment(\.dismiss) private var dismiss
    private let calendarSync = CalendarEventSync()
    @State private var event: PlannedEvent
    @State private var hasEndTime: Bool
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var isSaving = false

    init(editingEvent: PlannedEvent? = nil) {
        let event = editingEvent ?? PlannedEvent(startsAt: Date().addingTimeInterval(3600))
        _event = State(initialValue: event)
        _hasEndTime = State(initialValue: event.endsAt != nil)
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        eventImagePicker
                        plannedField("Event name".afLocalized, text: $event.name)
                        MapAddressField(title: "Event location".afLocalized, text: $event.location) { resolved in
                            event.locationLatitude = resolved.coordinate.latitude
                            event.locationLongitude = resolved.coordinate.longitude
                        }

                        DatePicker("Start time".afLocalized, selection: $event.startsAt)
                            .datePickerStyle(.compact)
                            .tint(Color.sceneAccent)
                            .foregroundStyle(.white)

                        Toggle("End time".afLocalized, isOn: $hasEndTime)
                            .tint(Color.sceneAccent)

                        if hasEndTime {
                            DatePicker(
                                "Ends".afLocalized,
                                selection: Binding(
                                    get: { event.endsAt ?? event.startsAt.addingTimeInterval(3600) },
                                    set: { event.endsAt = $0 }
                                )
                            )
                            .datePickerStyle(.compact)
                            .tint(Color.sceneAccent)
                            .foregroundStyle(.white)
                        }

                        Text("Notes".afLocalized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.sceneMuted)

                        TextEditor(text: $event.notes)
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(.white)
                            .frame(minHeight: 110)
                            .padding(10)
                            .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
                    }
                    .historyCard()

                    Button {
                        save()
                    } label: {
                        Label(isSaving ? "Saving...".afLocalized : "Save Planned Event".afLocalized, systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ScenePrimaryButtonStyle())
                    .disabled(isSaving)
                }
                .padding(20)
            }
        }
        .developerScreenID("320002", "PlannedEventEditorView")
        .navigationTitle("Plan Event".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                }
                .accessibilityLabel("Cancel".afLocalized)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    save()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                }
                .accessibilityLabel("Done".afLocalized)
            }
        }
        .onChange(of: hasEndTime) { newValue in
            if newValue, event.endsAt == nil {
                event.endsAt = event.startsAt.addingTimeInterval(3600)
            } else if !newValue {
                event.endsAt = nil
            }
        }
        .onChange(of: selectedImageItem) { newItem in
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                await MainActor.run {
                    event.imageData = data
                }
            }
        }
    }

    private var eventImagePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Event image".afLocalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.sceneAccent.opacity(0.10))

                    if let imageData = event.imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack {
                            Spacer()
                            HStack {
                                Label("Change image".afLocalized, systemImage: "photo.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 10)
                                    .frame(height: 30)
                                    .background(Color.sceneAccent, in: Capsule())
                                Spacer()
                            }
                            .padding(10)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.sceneAccent)
                            Text("Add event image".afLocalized)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(height: 150)
                .clipped()
            }

            if event.imageData != nil {
                Button(role: .destructive) {
                    event.imageData = nil
                    selectedImageItem = nil
                } label: {
                    Label("Remove image".afLocalized, systemImage: "trash")
                }
                .font(.caption.weight(.bold))
            }
        }
    }

    private func plannedField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            TextField("", text: text)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        event.name = event.name.trimmingCharacters(in: .whitespacesAndNewlines)
        event.location = event.location.trimmingCharacters(in: .whitespacesAndNewlines)
        event.notes = event.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            var eventToSave = event
            if let calendarID = await calendarSync.upsertCalendarEvent(eventToSave) {
                eventToSave.calendarEventIdentifier = calendarID
            }

            await MainActor.run {
                if incidentStore.plannedEvents.contains(where: { $0.id == eventToSave.id }) {
                    incidentStore.updatePlannedEvent(eventToSave)
                } else {
                    incidentStore.addPlannedEvent(eventToSave)
                }
                isSaving = false
                dismiss()
            }
        }
    }
}

private final class CalendarEventSync {
    private let eventStore = EKEventStore()

    func upsertCalendarEvent(_ plannedEvent: PlannedEvent) async -> String? {
        guard await requestAccess() else { return nil }

        let calendarEvent: EKEvent
        if let identifier = plannedEvent.calendarEventIdentifier,
           let existingEvent = eventStore.event(withIdentifier: identifier) {
            calendarEvent = existingEvent
        } else {
            calendarEvent = EKEvent(eventStore: eventStore)
            calendarEvent.calendar = eventStore.defaultCalendarForNewEvents
        }

        calendarEvent.title = plannedEvent.name.isEmpty ? "AidFlow Planned Event" : plannedEvent.name
        calendarEvent.location = plannedEvent.location
        calendarEvent.startDate = plannedEvent.startsAt
        calendarEvent.endDate = plannedEvent.endsAt ?? plannedEvent.startsAt.addingTimeInterval(3600)
        calendarEvent.notes = plannedEvent.notes

        do {
            try eventStore.save(calendarEvent, span: .thisEvent, commit: true)
            return calendarEvent.eventIdentifier
        } catch {
            return plannedEvent.calendarEventIdentifier
        }
    }

    func deleteCalendarEvent(identifier: String?) async {
        guard let identifier, await requestAccess(), let event = eventStore.event(withIdentifier: identifier) else { return }
        try? eventStore.remove(event, span: .thisEvent, commit: true)
    }

    private func requestAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .writeOnly, .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                if #available(iOS 17.0, *) {
                    eventStore.requestFullAccessToEvents { granted, _ in
                        continuation.resume(returning: granted)
                    }
                } else {
                    eventStore.requestAccess(to: .event) { granted, _ in
                        continuation.resume(returning: granted)
                    }
                }
            }
        @unknown default:
            return false
        }
    }
}

private struct HistoryIncidentRow: View {
    let incident: Incident

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: incident.kind == .patientRecord ? "doc.text.fill" : (incident.status == .active ? "waveform.path.ecg" : "checkmark.seal.fill"))
                .font(.title3)
                .foregroundStyle(incident.kind == .patientRecord ? Color.sceneAccent : (incident.status == .active ? Color.sceneAccent : Color.sceneSafe))
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(DateFormatter.sceneDateTime.string(from: incident.startedAt))
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(AppStrings.display(incident.kind.rawValue))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Color.sceneAccent, in: Capsule())
                }

                Text(incident.kind == .patientRecord ? AppStrings.text("Patient record - %@", incident.routineActionTitle.afLocalized) : AppStrings.text("%@ - %d timeline events", incident.routineActionTitle.afLocalized, incident.timeline.count))
                    .font(.subheadline)
                    .foregroundStyle(Color.sceneMuted)

                if let location = incident.location {
                    Text(location.address)
                        .font(.caption)
                        .foregroundStyle(Color.sceneMuted)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
        .frame(maxWidth: .infinity)
    }
}

private struct IncidentHistoryDetailView: View {
    @EnvironmentObject private var incidentStore: IncidentStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("developerModeEnabled") private var developerModeEnabled = false
    @State private var handoverExportArtifacts = HandoverExportArtifacts.empty
    @State private var showingIncidentEditor = false
    @State private var showingArrivalMode = false
    @State private var showingDeleteConfirmation = false
    @State private var editingTimelineEvent: TimelineEvent?
    let incident: Incident

    private var displayedIncident: Incident {
        incidentStore.incidentHistory().first { $0.id == incident.id } ?? incident
    }

    private var handoverText: String {
        incidentStore.generateHandover(for: displayedIncident)
    }

    private var handoverExportCacheKey: String {
        displayedIncident.handoverExportCacheKey
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    locationSection
                    patientHistorySection
                    vitalSignsSection
                    timelineSection
                    handoverSection
                }
                .padding(16)
            }
        }
        .developerScreenID("310002", "IncidentHistoryDetailView")
        .navigationTitle("Incident".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(displayedIncident.routineActionTitle.afLocalized) {
                    handleRoutineAction()
                }
                .fontWeight(.semibold)

                if let shareURL = handoverExportArtifacts.preferredShareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(
                        handoverExportArtifacts.pdfURL == nil
                        ? "Share handover document".afLocalized
                        : "Share handover PDF".afLocalized
                    )
                }

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash.fill")
                }
                .accessibilityLabel("Delete".afLocalized)
            }
        }
        .sheet(isPresented: $showingIncidentEditor) {
            NavigationStack {
                PatientRecordFormView(editingIncident: displayedIncident)
            }
        }
        .fullScreenCover(isPresented: $showingArrivalMode) {
            NavigationStack {
                ArrivalModeView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done".afLocalized) {
                                showingArrivalMode = false
                            }
                        }
                    }
            }
        }
        .sheet(item: $editingTimelineEvent) { event in
            IncidentTimelineEventEditor(event: event) { title, detail in
                saveTimelineEvent(event, title: title, detail: detail)
            }
        }
        .alert("Delete incident?".afLocalized, isPresented: $showingDeleteConfirmation) {
            Button("Delete".afLocalized, role: .destructive) {
                incidentStore.deleteIncident(id: displayedIncident.id)
                dismiss()
            }

            Button("Cancel".afLocalized, role: .cancel) {}
        } message: {
            Text("This removes this incident and handover history from this device.".afLocalized)
        }
        .onAppear {
            refreshHandoverExportArtifacts()
        }
        .onChange(of: handoverExportCacheKey) { _ in
            refreshHandoverExportArtifacts()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppStrings.display(displayedIncident.status.rawValue).uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)

            Text(AppStrings.display(displayedIncident.kind.rawValue))
                .font(.caption.weight(.bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Color.sceneAccent, in: Capsule())

            Text(DateFormatter.sceneDateTime.string(from: displayedIncident.startedAt))
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(AppStrings.text("%d timeline events", displayedIncident.timeline.count))
                .font(.subheadline)
                .foregroundStyle(Color.sceneMuted)

            let departure = displayedIncident.patientDeparture.trimmingCharacters(in: .whitespacesAndNewlines)
            if !departure.isEmpty {
                Text(AppStrings.text("Patient left via: %@", AppStrings.display(departure)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.12)
    }

    private var locationSection: some View {
        Button {
            guard let location = displayedIncident.location else { return }
            let encodedAddress = location.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "http://maps.apple.com/?ll=\(location.latitude),\(location.longitude)&q=\(encodedAddress)") {
                openURL(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Location".afLocalized)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if displayedIncident.location != nil {
                        Image(systemName: "map.fill")
                            .foregroundStyle(Color.sceneAccent)
                    }
                }

                if let location = displayedIncident.location {
                    Text(location.coordinateText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.sceneAccent)
                    Text(location.address)
                        .font(.subheadline)
                        .foregroundStyle(Color.sceneMuted)
                    if !incident.what3Words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(incident.what3Words)
                            .font(.subheadline)
                            .foregroundStyle(Color.sceneMuted)
                    }
                } else {
                    Text("No location recorded.".afLocalized)
                        .foregroundStyle(Color.sceneMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
        }
        .buttonStyle(.plain)
        .disabled(displayedIncident.location == nil)
    }

    private var patientHistorySection: some View {
        let profile = displayedIncident.patientProfile

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Patient History".afLocalized)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    showingIncidentEditor = true
                } label: {
                    Label("Edit".afLocalized, systemImage: "pencil")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
            }

            VStack(spacing: 8) {
                if developerModeEnabled {
                    detailLine("Name".afLocalized, patientName(for: profile))
                    detailLine("Date of Birth".afLocalized, profile.dateOfBirth)
                }
                detailLine("Age".afLocalized, profile.age)
                detailLine("Sex".afLocalized, profile.sex)
                if developerModeEnabled {
                    detailLine("Patient address".afLocalized, patientAddress(for: profile))
                    detailLine("Contact detail".afLocalized, profile.patientContactDetail)
                    detailLine("Emergency Contact Detail".afLocalized, emergencyContact(for: profile))
                }
                detailLine("Medical History".afLocalized, profile.medicalHistory)
                detailLine("Allergies".afLocalized, profile.allergies)
                detailLine("Medications".afLocalized, profile.medications)
                detailLine("Treatment".afLocalized, profile.treatment)
                detailLine("Event name".afLocalized, profile.eventName)
                detailLine("Event location".afLocalized, profile.eventLocation)
                detailLine("Event History".afLocalized, profile.eventHistory)
                detailLine("Injury".afLocalized, profile.injury)
                detailLine("Injury body part".afLocalized, profile.injuryBodyPart)
                detailLine("Notes".afLocalized, displayedIncident.patientNotes)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Timeline".afLocalized)
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(displayedIncident.timeline.sorted { $0.timestamp < $1.timestamp }) { event in
                TimelineRow(event: event) {
                    editingTimelineEvent = event
                }
            }
        }
    }

    private var vitalSignsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Vital Signs".afLocalized)
                .font(.headline)
                .foregroundStyle(.white)

            if displayedIncident.vitalSigns.isEmpty {
                Text("No vital signs recorded.".afLocalized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .liquidGlass(tint: Color.sceneAccent, opacity: 0.06)
            } else {
                VStack(spacing: 8) {
                    ForEach(displayedIncident.vitalSigns.sorted { $0.recordedAt > $1.recordedAt }) { record in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(DateFormatter.sceneDateTime.string(from: record.recordedAt))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)

                            Text(record.summaryParts.isEmpty ? "No values recorded.".afLocalized : record.summaryParts.joined(separator: "  "))
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(Color.sceneMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
    }

    private var handoverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Handover Document".afLocalized)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                if let handoverPDFURL = handoverExportArtifacts.pdfURL {
                    ShareLink(item: handoverPDFURL) {
                        Label("Share PDF".afLocalized, systemImage: "doc.richtext.fill")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.sceneAccent)
                } else if let handoverURL = handoverExportArtifacts.documentURL {
                    ShareLink(item: handoverURL) {
                        Label("Share Text".afLocalized, systemImage: "doc.text.fill")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.sceneAccent)
                }
            }

            Text(handoverText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
        }
    }

    private func refreshHandoverExportArtifacts() {
        handoverExportArtifacts = incidentStore.handoverExportArtifacts(for: displayedIncident)
    }

    private func saveTimelineEvent(_ event: TimelineEvent, title: String, detail: String?) {
        var updatedIncident = displayedIncident
        guard let index = updatedIncident.timeline.firstIndex(where: { $0.id == event.id }) else { return }
        updatedIncident.timeline[index].title = title
        updatedIncident.timeline[index].detail = detail
        incidentStore.updateIncident(updatedIncident)
        editingTimelineEvent = nil
    }

    private func handleRoutineAction() {
        if displayedIncident.kind == .patientRecord {
            showingIncidentEditor = true
            return
        }

        switch displayedIncident.status {
        case .active:
            showingArrivalMode = true
        case .handedOver:
            incidentStore.reopenIncidentForEditing(displayedIncident)
            showingArrivalMode = true
        case .record, .training:
            showingIncidentEditor = true
        }
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        return HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneMuted)
                .frame(width: 118, alignment: .leading)

            Text(trimmedValue.isEmpty ? "Not recorded".afLocalized : AppStrings.display(trimmedValue))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func patientName(for profile: PatientProfile) -> String {
        let name = [profile.firstName, profile.surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? profile.fullName : name
    }

    private func patientAddress(for profile: PatientProfile) -> String {
        [
            profile.patientUnit,
            profile.patientStreet,
            profile.patientSuburb,
            profile.patientState,
            profile.patientPostcode
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }

    private func emergencyContact(for profile: PatientProfile) -> String {
        [
            profile.emergencyContactDetailName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? profile.emergencyContactName : profile.emergencyContactDetailName,
            profile.emergencyContactDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? profile.emergencyContactPhone : profile.emergencyContactDetail
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " - ")
    }
}

private extension Incident {
    var routineActionTitle: String {
        if kind == .patientRecord {
            return "Edit"
        }

        switch status {
        case .active:
            return "Continue"
        case .handedOver:
            return "Recover"
        case .record, .training:
            return "Edit"
        }
    }
}

private struct IncidentTimelineEventEditor: View {
    let event: TimelineEvent
    let onSave: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var detail: String

    init(event: TimelineEvent, onSave: @escaping (String, String?) -> Void) {
        self.event = event
        self.onSave = onSave
        _title = State(initialValue: event.title)
        _detail = State(initialValue: event.detail ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()

                VStack(spacing: 16) {
                    TextField("Event title".afLocalized, text: $title)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .padding(14)
                        .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)

                    TextEditor(text: $detail)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(.white)
                        .frame(minHeight: 170)
                        .padding(10)
                        .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Edit Event".afLocalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel".afLocalized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save".afLocalized) {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedTitle.isEmpty else { return }
                        onSave(trimmedTitle, trimmedDetail.isEmpty ? nil : trimmedDetail)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
