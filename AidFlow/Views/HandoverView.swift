import SwiftUI

struct HandoverView: View {
    @EnvironmentObject private var incidentStore: IncidentStore
    @State private var patientNotes = ""
    @State private var what3Words = ""
    @State private var patientDeparture = PatientDeparture.ambulance.rawValue
    @State private var closedIncident: Incident?
    @State private var closedExportArtifacts = HandoverExportArtifacts.empty
    @State private var exportOptions = HandoverExportOptions.full
    let onDone: () -> Void

    init(onDone: @escaping () -> Void = {}) {
        self.onDone = onDone
    }

    private var handoverText: String {
        if let closedIncident {
            return incidentStore.generateHandover(for: closedIncident, options: exportOptions)
        }

        guard let incident = incidentStore.currentIncident else {
            return "No active incident.".afLocalized
        }
        return incidentStore.generateHandover(for: finalPreviewIncident(from: incident), options: exportOptions)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()

                if let closedIncident {
                    CaseClosureReceiptView(
                        incident: closedIncident,
                        handoverText: handoverText,
                        handoverURL: closedExportArtifacts.documentURL,
                        handoverPDFURL: closedExportArtifacts.pdfURL,
                        onEdit: {
                            editClosedIncident(closedIncident)
                        },
                        onDone: onDone
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                } else {
                    handoverEditor
                }
            }
            .developerScreenID(
                closedIncident == nil ? "230001" : "230002",
                closedIncident == nil ? "HandoverView.Editor" : "HandoverView.FinalReport"
            )
            .navigationTitle("Handover".afLocalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                patientNotes = incidentStore.currentIncident?.patientNotes ?? ""
                what3Words = incidentStore.currentIncident?.what3Words ?? ""
                let savedDeparture = incidentStore.currentIncident?.patientDeparture ?? ""
                if !savedDeparture.isEmpty {
                    patientDeparture = savedDeparture
                }
            }
        }
    }

    private var handoverEditor: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    closeCasePanel
                    locationPanel
                    what3WordsField
                    patientNotesEditor
                    exportOptionsPanel
                    handoverPreviewPanel
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            .clipped()

            closeCaseActionBar
        }
    }

    private var closeCaseActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)

            Button {
                if let incident = incidentStore.finishIncident(patientDeparture: patientDeparture) {
                    closedExportArtifacts = incidentStore.handoverExportArtifacts(for: incident, options: exportOptions)
                    closedIncident = incident
                }
            } label: {
                Label("Close Case".afLocalized, systemImage: "checkmark.seal.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScenePrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background {
            Color.sceneBackground
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var what3WordsField: some View {
        TextField("what3words, e.g. ///filled.count.soap".afLocalized, text: $what3Words)
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(.white)
            .tint(Color.sceneAccent)
            .padding(14)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
            .onChange(of: what3Words) { newValue in
                incidentStore.updateWhat3Words(newValue)
            }
    }

    private var patientNotesEditor: some View {
        TextEditor(text: $patientNotes)
            .scrollContentBackground(.hidden)
            .foregroundStyle(.white)
            .tint(Color.sceneAccent)
            .frame(minHeight: 124)
            .padding(10)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
            .overlay(alignment: .topLeading) {
                if patientNotes.isEmpty {
                    Text("Patient notes, signs, medical history...".afLocalized)
                        .foregroundStyle(Color.sceneMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: patientNotes) { newValue in
                incidentStore.updatePatientNotes(newValue)
            }
    }

    private var handoverPreviewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Report Preview".afLocalized, systemImage: "doc.text.magnifyingglass")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .textCase(.uppercase)

            Text(handoverText)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
    }

    private var closeCasePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Close the Case".afLocalized)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .textCase(.uppercase)

            Text("Patient left via".afLocalized)
                .font(.headline)
                .foregroundStyle(.white)

            Picker("Patient left via".afLocalized, selection: $patientDeparture) {
                ForEach(PatientDeparture.allCases) { departure in
                    Text(AppStrings.display(departure.rawValue)).tag(departure.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: patientDeparture) { newValue in
                incidentStore.updatePatientDeparture(newValue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.12)
    }

    private var exportOptionsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Report Sections".afLocalized)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.sceneAccent)
                    .textCase(.uppercase)

                Text("Choose what appears in the preview and exported PDF.".afLocalized)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                HandoverExportToggle(title: "Case overview".afLocalized, isOn: $exportOptions.includeCaseOverview)
                HandoverExportToggle(title: "Patient summary".afLocalized, isOn: $exportOptions.includePatientSummary)
                HandoverExportToggle(title: "Event and injury summary".afLocalized, isOn: $exportOptions.includeEventSummary)
                HandoverExportToggle(title: "Clinical history".afLocalized, isOn: $exportOptions.includeClinicalHistory)
                HandoverExportToggle(title: "Vital signs".afLocalized, isOn: $exportOptions.includeVitalSigns)
                HandoverExportToggle(title: "Location".afLocalized, isOn: $exportOptions.includeLocation)
                HandoverExportToggle(title: "Timeline and actions".afLocalized, isOn: $exportOptions.includeTimeline)
                HandoverExportToggle(title: "Responder signature".afLocalized, isOn: $exportOptions.includeSignature)
                HandoverExportToggle(title: "Privacy and safety notice".afLocalized, isOn: $exportOptions.includeLegalFooter)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
    }

    private func finalPreviewIncident(from incident: Incident) -> Incident {
        var previewIncident = incident
        previewIncident.status = .handedOver
        previewIncident.patientDeparture = patientDeparture
        return previewIncident
    }

    private func editClosedIncident(_ incident: Incident) {
        incidentStore.reopenIncidentForEditing(incident)
        patientNotes = incident.patientNotes
        what3Words = incident.what3Words
        patientDeparture = incident.patientDeparture.isEmpty ? PatientDeparture.ambulance.rawValue : incident.patientDeparture
        closedIncident = nil
        closedExportArtifacts = .empty
    }

    private var locationPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Scene Location".afLocalized, systemImage: "location.fill")
                .font(.headline)
                .foregroundStyle(.white)

            if let location = incidentStore.currentIncident?.location {
                Text(location.coordinateText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.sceneAccent)

                Text(location.address)
                    .font(.subheadline)
                    .foregroundStyle(Color.sceneMuted)
            } else {
                Text("Location not captured yet.".afLocalized)
                    .font(.subheadline)
                    .foregroundStyle(Color.sceneMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
    }
}

private enum PatientDeparture: String, CaseIterable, Identifiable {
    case ambulance = "Ambulance"
    case family = "Family"
    case selfDischarged = "Self"

    var id: String { rawValue }
}

private struct CaseClosureReceiptView: View {
    let incident: Incident
    let handoverText: String
    let handoverURL: URL?
    let handoverPDFURL: URL?
    let onEdit: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            receiptHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("AIDFLOW FINAL REPORT".afLocalized)
                        .font(.headline.monospaced().weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .center)

                    Divider()

                    Text(handoverText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.black)
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.94))
                }
                .overlay(alignment: .top) {
                    ReceiptPerforation()
                        .fill(Color.sceneBackground)
                        .frame(height: 10)
                        .offset(y: -1)
                }
                .overlay(alignment: .bottom) {
                    ReceiptPerforation()
                        .fill(Color.sceneBackground)
                        .frame(height: 10)
                        .rotationEffect(.degrees(180))
                        .offset(y: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            receiptActions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.bottom, 12)
    }

    private var receiptHeader: some View {
        VStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title)
                .foregroundStyle(Color.sceneSafe)

            Text("Case Closed".afLocalized)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(DateFormatter.sceneDateTime.string(from: incident.startedAt))
                .font(.caption)
                .foregroundStyle(Color.sceneMuted)
        }
    }

    private var receiptActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                shareAction
                editAction
                doneAction
            }

            VStack(spacing: 10) {
                shareAction
                HStack(spacing: 10) {
                    editAction
                    doneAction
                }
            }
        }
    }

    @ViewBuilder
    private var shareAction: some View {
        if let handoverPDFURL {
            ShareLink(item: handoverPDFURL) {
                HandoverActionLabel(title: "PDF".afLocalized, systemImage: "doc.richtext.fill")
            }
            .buttonStyle(SceneSecondaryButtonStyle())
            .accessibilityLabel("Share handover PDF".afLocalized)
        } else if let handoverURL {
            ShareLink(item: handoverURL) {
                HandoverActionLabel(title: "Text".afLocalized, systemImage: "doc.text.fill")
            }
            .buttonStyle(SceneSecondaryButtonStyle())
            .accessibilityLabel("Share handover document".afLocalized)
        }
    }

    private var editAction: some View {
        Button {
            onEdit()
        } label: {
            HandoverActionLabel(title: "Edit".afLocalized, systemImage: "pencil")
        }
        .buttonStyle(SceneSecondaryButtonStyle())
    }

    private var doneAction: some View {
        Button {
            onDone()
        } label: {
            HandoverActionLabel(title: "Done".afLocalized, systemImage: "house.fill")
        }
        .buttonStyle(ScenePrimaryButtonStyle())
    }
}

private struct HandoverActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(maxWidth: .infinity)
    }
}

private struct HandoverExportToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .toggleStyle(.switch)
        .tint(Color.sceneAccent)
        .accessibilityLabel(title)
    }
}

private struct ReceiptPerforation: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let diameter = rect.height
        var x: CGFloat = 0

        while x < rect.width + diameter {
            path.addEllipse(in: CGRect(x: x - diameter / 2, y: 0, width: diameter, height: diameter))
            x += diameter * 1.45
        }

        return path
    }
}
