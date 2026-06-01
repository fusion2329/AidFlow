import SwiftUI

struct TimelineView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()

                TimelineViewContent()
                    .padding(20)
            }
            .developerScreenID("220003", "TimelineView")
            .navigationTitle("Timeline".afLocalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

struct TimelineViewContent: View {
    @EnvironmentObject private var incidentStore: IncidentStore
    @State private var note = ""
    @State private var eventTime = Date()
    @State private var category: TimelineCategory = .observation

    private var incident: Incident? {
        incidentStore.currentIncident
    }

    var body: some View {
        VStack(spacing: 16) {
            if let incident {
                noteInput

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(incident.timeline.sorted { $0.timestamp < $1.timestamp }) { event in
                            TimelineRow(event: event, showsEditButton: false) {}
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                SceneEmptyState(
                    title: "No active incident".afLocalized,
                    systemImage: "clock.badge.questionmark"
                )
            }
        }
    }

    private var noteInput: some View {
        VStack(spacing: 10) {
            TextField("Timeline note".afLocalized, text: $note)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .padding(14)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)

            HStack(spacing: 10) {
                DatePicker("Time".afLocalized, selection: $eventTime, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .tint(Color.sceneAccent)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)

                Picker("Type".afLocalized, selection: $category) {
                    ForEach(TimelineCategory.allCases) { category in
                        Text(AppStrings.display(category.rawValue)).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
            }

            Button {
                let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                incidentStore.addTimelineEvent(title: trimmed, detail: nil, category: category, timestamp: eventTime)
                note = ""
                eventTime = Date()
                category = .observation
            } label: {
                Label("Add to Timeline".afLocalized, systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SceneSecondaryButtonStyle())
        }
    }
}

struct TimelineRow: View {
    let event: TimelineEvent
    var showsEditButton = true
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(DateFormatter.sceneTime.string(from: event.timestamp))
                .font(.headline.monospacedDigit())
                .foregroundStyle(Color.sceneAccent)
                .frame(width: 58, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text(AppStrings.display(event.title))
                    .font(.headline)
                    .foregroundStyle(.white)

                if let detail = event.detail, !detail.isEmpty {
                    Text(AppStrings.display(detail))
                        .font(.subheadline)
                        .foregroundStyle(Color.sceneMuted)
                }

                Text(AppStrings.display(event.category.rawValue))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
            }

            Spacer()

            if showsEditButton {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.headline)
                        .foregroundStyle(Color.sceneAccent)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(SceneCardButtonStyle())
                .accessibilityLabel("Edit timeline event".afLocalized)
            }
        }
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
    }
}

private struct TimelineEventEditor: View {
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
                        .frame(minHeight: 160)
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
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
