import Foundation
import UIKit

private struct PDFField {
    let label: String
    let value: String
}

struct HandoverExportOptions: Equatable {
    var includeCaseOverview = true
    var includePatientSummary = true
    var includeEventSummary = true
    var includeClinicalHistory = true
    var includeVitalSigns = true
    var includeLocation = true
    var includeTimeline = true
    var includeSignature = true
    var includeLegalFooter = true

    static let full = HandoverExportOptions()
}

struct HandoverExportArtifacts: Equatable {
    var documentURL: URL?
    var pdfURL: URL?

    var preferredShareURL: URL? {
        pdfURL ?? documentURL
    }

    static let empty = HandoverExportArtifacts()
}

final class IncidentStore: ObservableObject {
    @Published var currentIncident: Incident? {
        didSet { saveDatabase() }
    }
    @Published var pastIncidents: [Incident] = [] {
        didSet { saveDatabase() }
    }
    @Published var plannedEvents: [PlannedEvent] = [] {
        didSet { saveDatabase() }
    }
    @Published private(set) var hasLoadedDatabase = false

    private let handoverFormatter = DateFormatter.sceneTime
    private let databaseURL: URL
    private let databaseQueue = DispatchQueue(label: "com.aidflow.database", qos: .utility)
    private var pendingDatabaseSave: DispatchWorkItem?
    private var hasStartedDatabaseLoad = false
    private var isRestoringDatabase = false
    private var isBatchingDatabaseChanges = false
    private var needsDatabaseSaveAfterBatch = false
    private var lastQueuedDatabase: IncidentDatabase?
    private var lastWrittenDatabase: IncidentDatabase?

    init() {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folderURL = supportURL.appendingPathComponent("AidFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        databaseURL = folderURL.appendingPathComponent("incident-database.json")
    }

    func loadDatabaseIfNeeded() {
        guard !hasStartedDatabaseLoad else { return }
        hasStartedDatabaseLoad = true
        let databaseURL = databaseURL

        databaseQueue.async {
            let database = Self.readDatabase(from: databaseURL)

            DispatchQueue.main.async {
                self.isRestoringDatabase = true
                if let database {
                    self.currentIncident = database.currentIncident
                    self.pastIncidents = database.pastIncidents
                    self.plannedEvents = database.plannedEvents
                }
                self.isRestoringDatabase = false
                self.hasLoadedDatabase = true
                let loadedSnapshot = self.currentDatabaseSnapshot()
                self.lastQueuedDatabase = loadedSnapshot
                self.lastWrittenDatabase = loadedSnapshot
                if let currentIncident = self.currentIncident {
                    LiveActivityManager.shared.startOrUpdate(for: currentIncident)
                } else {
                    LiveActivityManager.shared.end(for: nil)
                }
            }
        }
    }

    func flushDatabase() {
        guard hasLoadedDatabase, !isRestoringDatabase else { return }

        pendingDatabaseSave?.cancel()
        pendingDatabaseSave = nil

        let database = currentDatabaseSnapshot()
        guard database != lastWrittenDatabase else {
            lastQueuedDatabase = database
            return
        }

        let didWrite = databaseQueue.sync {
            write(database)
        }
        if didWrite {
            lastQueuedDatabase = database
            lastWrittenDatabase = database
        } else {
            lastQueuedDatabase = lastWrittenDatabase
        }
    }

    func startIncident(plannedEvent: PlannedEvent? = nil) {
        let previousIncident = currentIncident
        var incident = Incident()
        if let plannedEvent {
            incident.patientProfile = plannedEvent.profileTemplate
        }
        incident.timeline.append(
            TimelineEvent(
                timestamp: incident.startedAt,
                title: "Arrived on scene",
                detail: plannedEvent.map { "Incident timer started for \($0.name)." } ?? "Incident timer started.",
                category: .arrival
            )
        )
        performDatabaseMutation {
            currentIncident = incident
        }
        if let previousIncident {
            LiveActivityManager.shared.end(for: previousIncident)
        }
        LiveActivityManager.shared.startOrUpdate(for: incident)
    }

    func savePatientRecord(
        profile: PatientProfile,
        notes: String,
        location: IncidentLocation? = nil,
        vitalSigns: [VitalSignsRecord] = [],
        treatmentEvents: [TimelineEvent] = []
    ) {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        var record = Incident(
            kind: .patientRecord,
            status: .record,
            patientProfile: profile,
            patientNotes: trimmedNotes,
            location: location,
            vitalSigns: vitalSigns.sorted { $0.recordedAt < $1.recordedAt }
        )
        record.timeline.append(
            TimelineEvent(
                timestamp: record.startedAt,
                title: "Patient record created",
                detail: "Standalone patient record form saved.",
                category: .observation
            )
        )
        if let location {
            record.timeline.append(
                TimelineEvent(
                    timestamp: location.capturedAt,
                    title: "Event location captured",
                    detail: "\(location.coordinateText)\n\(location.address)",
                    category: .observation
                )
            )
        }
        record.timeline.append(contentsOf: treatmentEvents)
        record.timeline.sort { $0.timestamp < $1.timestamp }
        pastIncidents.insert(record, at: 0)
    }

    func record(title: String, detail: String? = nil, category: TimelineCategory = .observation) {
        guard currentIncident != nil else { return }
        currentIncident?.timeline.append(
            TimelineEvent(title: title, detail: detail, category: category)
        )
        updateLiveActivity()
    }

    func updatePatientNotes(_ notes: String) {
        currentIncident?.patientNotes = notes
    }

    func updatePatientDeparture(_ departure: String) {
        currentIncident?.patientDeparture = departure
    }

    func updatePatientProfile(_ profile: PatientProfile) {
        currentIncident?.patientProfile = profile
    }

    func applyPlannedEventToCurrentIncident(_ event: PlannedEvent) {
        guard var profile = currentIncident?.patientProfile else { return }
        profile.applyPlannedEvent(event)
        performDatabaseMutation {
            currentIncident?.patientProfile = profile
            currentIncident?.timeline.append(
                TimelineEvent(
                    title: "Planned event applied",
                    detail: "\(event.name)\n\(event.location)\n\(event.timeSummary)",
                    category: .observation
                )
            )
            sortCurrentIncidentTimeline()
        }
        updateLiveActivity()
    }

    func addPlannedEvent(_ event: PlannedEvent) {
        plannedEvents.insert(event, at: 0)
        sortPlannedEvents()
    }

    func updatePlannedEvent(_ event: PlannedEvent) {
        guard let index = plannedEvents.firstIndex(where: { $0.id == event.id }) else { return }
        plannedEvents[index] = event
        sortPlannedEvents()
    }

    func deletePlannedEvent(id: UUID) {
        plannedEvents.removeAll { $0.id == id }
    }

    func upcomingPlannedEvents() -> [PlannedEvent] {
        plannedEvents
            .filter(\.isUpcoming)
            .sorted { $0.startsAt < $1.startsAt }
    }

    func pastPlannedEvents() -> [PlannedEvent] {
        plannedEvents
            .filter { !$0.isUpcoming }
            .sorted { $0.startsAt > $1.startsAt }
    }

    func updateWhat3Words(_ words: String) {
        currentIncident?.what3Words = words
    }

    func updateLocation(_ location: IncidentLocation) {
        guard currentIncident != nil else { return }
        performDatabaseMutation {
            currentIncident?.location = location
            currentIncident?.timeline.append(
                TimelineEvent(
                    title: "Location captured",
                    detail: "\(location.coordinateText)\n\(location.address)",
                    category: .observation
                )
            )
            sortCurrentIncidentTimeline()
        }
        updateLiveActivity()
    }

    func addVitalSigns(_ vitalSigns: VitalSignsRecord) {
        guard currentIncident != nil else { return }
        performDatabaseMutation {
            currentIncident?.vitalSigns.append(vitalSigns)
            currentIncident?.vitalSigns.sort { $0.recordedAt < $1.recordedAt }
            currentIncident?.timeline.append(
                TimelineEvent(
                    sourceID: vitalSigns.id,
                    timestamp: vitalSigns.recordedAt,
                    title: vitalSignsTimelineTitle(for: vitalSigns),
                    detail: vitalSignsTimelineDetail(for: vitalSigns),
                    category: .observation
                )
            )
            sortCurrentIncidentTimeline()
        }
        updateLiveActivity()
    }

    func updateVitalSigns(_ vitalSigns: VitalSignsRecord) {
        guard let index = currentIncident?.vitalSigns.firstIndex(where: { $0.id == vitalSigns.id }) else { return }
        let previousRecord = currentIncident?.vitalSigns[index]
        performDatabaseMutation {
            currentIncident?.vitalSigns[index] = vitalSigns
            currentIncident?.vitalSigns.sort { $0.recordedAt < $1.recordedAt }
            updateVitalSignsTimelineEvent(from: previousRecord, to: vitalSigns)
        }
        updateLiveActivity()
    }

    func deleteVitalSigns(id: UUID) {
        guard currentIncident != nil else { return }
        let removedRecords = currentIncident?.vitalSigns.filter { $0.id == id } ?? []
        performDatabaseMutation {
            currentIncident?.vitalSigns.removeAll { $0.id == id }
            for record in removedRecords {
                deleteVitalSignsTimelineEvent(for: record)
            }
        }
        updateLiveActivity()
    }

    func addPupilAssessment(_ assessment: PupilAssessment, to incidentID: UUID) {
        let vitalSigns = VitalSignsRecord(
            recordedAt: assessment.recordedAt,
            pupilAssessment: assessment,
            notes: assessment.notes
        )
        let timelineEvent = TimelineEvent(
            sourceID: vitalSigns.id,
            timestamp: assessment.recordedAt,
            title: vitalSignsTimelineTitle(for: vitalSigns),
            detail: vitalSignsTimelineDetail(for: vitalSigns),
            category: .observation
        )

        if currentIncident?.id == incidentID {
            performDatabaseMutation {
                currentIncident?.vitalSigns.append(vitalSigns)
                currentIncident?.vitalSigns.sort { $0.recordedAt < $1.recordedAt }
                currentIncident?.timeline.append(timelineEvent)
                sortCurrentIncidentTimeline()
            }
            updateLiveActivity()
            return
        }

        guard let index = pastIncidents.firstIndex(where: { $0.id == incidentID }) else { return }
        performDatabaseMutation {
            pastIncidents[index].vitalSigns.append(vitalSigns)
            pastIncidents[index].vitalSigns.sort { $0.recordedAt < $1.recordedAt }
            pastIncidents[index].timeline.append(timelineEvent)
            pastIncidents[index].timeline.sort { $0.timestamp < $1.timestamp }
        }
    }

    func updateArrivalStepIndex(_ stepIndex: Int) {
        guard currentIncident != nil else { return }
        let boundedIndex = min(max(stepIndex, 0), ArrivalFlow.steps.count)
        currentIncident?.arrivalStepIndex = boundedIndex
        updateLiveActivity()
    }

    func updateTimelineEvent(id: UUID, title: String, detail: String?) {
        guard let index = currentIncident?.timeline.firstIndex(where: { $0.id == id }) else { return }
        currentIncident?.timeline[index].title = title
        currentIncident?.timeline[index].detail = detail
    }

    func addTimelineEvent(title: String, detail: String?, category: TimelineCategory, timestamp: Date) {
        guard currentIncident != nil else { return }
        currentIncident?.timeline.append(
            TimelineEvent(timestamp: timestamp, title: title, detail: detail, category: category)
        )
        sortCurrentIncidentTimeline()
        updateLiveActivity()
    }

    @discardableResult
    func finishIncident(patientDeparture: String? = nil) -> Incident? {
        guard var incident = currentIncident else { return nil }
        let departure = patientDeparture?.trimmingCharacters(in: .whitespacesAndNewlines) ?? incident.patientDeparture
        incident.patientDeparture = departure
        incident.status = .handedOver
        incident.timeline.append(
            TimelineEvent(
                title: "Case closed",
                detail: departure.isEmpty ? "Incident marked as handed over." : "Patient left via: \(departure)",
                category: .escalation
            )
        )
        performDatabaseMutation {
            pastIncidents.removeAll { $0.id == incident.id }
            pastIncidents.insert(incident, at: 0)
            currentIncident = nil
        }
        LiveActivityManager.shared.end(for: incident)
        return incident
    }

    func reopenIncidentForEditing(_ incident: Incident) {
        var editableIncident = incident
        editableIncident.status = .active

        if editableIncident.timeline.last?.title == "Case closed" {
            editableIncident.timeline.removeLast()
        }

        performDatabaseMutation {
            pastIncidents.removeAll { $0.id == incident.id }
            currentIncident = editableIncident
        }
        LiveActivityManager.shared.startOrUpdate(for: editableIncident)
    }

    func deleteIncident(id: UUID) {
        let incidentToEnd = currentIncident?.id == id ? currentIncident : nil
        performDatabaseMutation {
            if currentIncident?.id == id {
                currentIncident = nil
            }
            pastIncidents.removeAll { $0.id == id }
        }
        if let incidentToEnd {
            LiveActivityManager.shared.end(for: incidentToEnd)
        }
    }

    func deleteIncidents(ids: Set<UUID>) {
        let incidentToEnd = currentIncident.flatMap { ids.contains($0.id) ? $0 : nil }
        performDatabaseMutation {
            if let currentIncident, ids.contains(currentIncident.id) {
                self.currentIncident = nil
            }
            pastIncidents.removeAll { ids.contains($0.id) }
        }
        if let incidentToEnd {
            LiveActivityManager.shared.end(for: incidentToEnd)
        }
    }

    func updateIncident(_ incident: Incident) {
        if currentIncident?.id == incident.id {
            currentIncident = incident
            updateLiveActivity()
            return
        }

        guard let index = pastIncidents.firstIndex(where: { $0.id == incident.id }) else { return }
        pastIncidents[index] = incident
    }

    func incidentHistory() -> [Incident] {
        if let currentIncident {
            return [currentIncident] + pastIncidents
        }
        return pastIncidents
    }

    func handoverDocumentURL(for incident: Incident, options: HandoverExportOptions = .full) -> URL? {
        let text = generateHandover(for: incident, options: options)
        let filenameDate = DateFormatter.fileSafeDateTime.string(from: incident.startedAt)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AidFlow-Handover-\(filenameDate)")
            .appendingPathExtension("txt")

        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    func handoverPDFURL(for incident: Incident, options: HandoverExportOptions = .full) -> URL? {
        let filenameDate = DateFormatter.fileSafeDateTime.string(from: incident.startedAt)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AidFlow-Handover-\(filenameDate)")
            .appendingPathExtension("pdf")

        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let margin: CGFloat = 30
        let contentBottom = pageRect.height - 34
        let contentWidth = pageRect.width - margin * 2
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let profile = incident.patientProfile
        let accent = UIColor(red: 0.06, green: 0.36, blue: 0.31, alpha: 1)
        let accentLight = UIColor(red: 0.87, green: 0.96, blue: 0.93, alpha: 1)
        let border = UIColor(red: 0.63, green: 0.70, blue: 0.71, alpha: 1)
        let softFill = UIColor(red: 0.96, green: 0.98, blue: 0.98, alpha: 1)
        let titleFont = UIFont.boldSystemFont(ofSize: 17)
        let sectionFont = UIFont.boldSystemFont(ofSize: 9.5)
        let labelFont = UIFont.boldSystemFont(ofSize: 7.2)
        let valueFont = UIFont.systemFont(ofSize: 8.8, weight: .regular)
        let tableFont = UIFont.systemFont(ofSize: 7.4, weight: .regular)
        let tableHeaderFont = UIFont.boldSystemFont(ofSize: 7.4)
        let footerFont = UIFont.systemFont(ofSize: 7.5, weight: .semibold)

        let patientName = pdfPatientName(for: profile)
        let patientAddress = pdfPatientAddress(for: profile)
        let emergencyContact = pdfEmergencyContact(for: profile)
        let departure = incident.patientDeparture.trimmingCharacters(in: .whitespacesAndNewlines)
        let includePatientIdentity = UserDefaults.standard.bool(forKey: "developerModeEnabled")

        do {
            try renderer.writePDF(to: url) { context in
                var pageNumber = 0
                var y: CGFloat = margin

                func beginPage() {
                    context.beginPage()
                    pageNumber += 1
                    y = drawPDFHeader(
                        in: context.cgContext,
                        pageRect: pageRect,
                        margin: margin,
                        accent: accent,
                        titleFont: titleFont,
                        footerFont: footerFont,
                        incident: incident
                    )
                }

                func drawFooter() {
                    let footer = "\("AidFlow".afLocalized)  |  \("Training and documentation aid".afLocalized)  |  \("Page".afLocalized) \(pageNumber)"
                    drawPDFText(
                        footer,
                        in: CGRect(x: margin, y: pageRect.height - 24, width: contentWidth, height: 12),
                        font: footerFont,
                        color: UIColor.darkGray,
                        alignment: .right
                    )
                }

                func ensure(_ height: CGFloat) {
                    if y + height > contentBottom {
                        drawFooter()
                        beginPage()
                    }
                }

                beginPage()

                if options.includeCaseOverview {
                    let caseRows = [
                        PDFField(label: "Record type".afLocalized, value: AppStrings.display(incident.kind.rawValue)),
                        PDFField(label: "Started".afLocalized, value: DateFormatter.sceneDateTime.string(from: incident.startedAt)),
                        PDFField(label: "Status".afLocalized, value: AppStrings.display(incident.status.rawValue)),
                        PDFField(label: "Patient left via".afLocalized, value: departure.isEmpty ? "Not recorded".afLocalized : AppStrings.display(departure))
                    ]
                    ensure(pdfFieldSectionHeight(fields: caseRows, width: contentWidth, columns: 4, valueFont: valueFont))
                    y = drawPDFFieldSection(
                        title: "CASE OVERVIEW".afLocalized,
                        fields: caseRows,
                        x: margin,
                        y: y,
                        width: contentWidth,
                        columns: 4,
                        accent: accent,
                        accentLight: accentLight,
                        border: border,
                        softFill: softFill,
                        sectionFont: sectionFont,
                        labelFont: labelFont,
                        valueFont: valueFont
                    ) + 8
                }

                let patientRows = includePatientIdentity ? [
                    PDFField(label: "Name".afLocalized, value: pdfRecorded(patientName)),
                    PDFField(label: "Date of birth".afLocalized, value: pdfRecorded(profile.dateOfBirth)),
                    PDFField(label: "Age".afLocalized, value: pdfRecorded(profile.age)),
                    PDFField(label: "Sex".afLocalized, value: pdfRecorded(AppStrings.display(profile.sex))),
                    PDFField(label: "Patient contact".afLocalized, value: pdfRecorded(profile.patientContactDetail)),
                    PDFField(label: "Emergency contact".afLocalized, value: pdfRecorded(emergencyContact)),
                    PDFField(label: "Patient address".afLocalized, value: pdfRecorded(patientAddress))
                ] : [
                    PDFField(label: "Age".afLocalized, value: pdfRecorded(profile.age)),
                    PDFField(label: "Sex".afLocalized, value: pdfRecorded(AppStrings.display(profile.sex)))
                ]
                if options.includePatientSummary {
                    ensure(pdfFieldSectionHeight(fields: patientRows, width: contentWidth, columns: 2, valueFont: valueFont))
                    y = drawPDFFieldSection(
                        title: "PATIENT SUMMARY".afLocalized,
                        fields: patientRows,
                        x: margin,
                        y: y,
                        width: contentWidth,
                        columns: 2,
                        accent: accent,
                        accentLight: accentLight,
                        border: border,
                        softFill: softFill,
                        sectionFont: sectionFont,
                        labelFont: labelFont,
                        valueFont: valueFont
                    ) + 8
                }

                let eventRows = [
                    PDFField(label: "Event name".afLocalized, value: pdfKnown(profile.eventName)),
                    PDFField(label: "Event location".afLocalized, value: pdfKnown(profile.eventLocation)),
                    PDFField(label: "Event time".afLocalized, value: pdfKnown(profile.eventStartTime)),
                    PDFField(label: "What happened".afLocalized, value: pdfKnown(profile.eventHistory)),
                    PDFField(label: "Injuries / concerns".afLocalized, value: pdfKnown(profile.injury)),
                    PDFField(label: "Body part(s)".afLocalized, value: pdfKnown(profile.injuryBodyPart))
                ]
                if options.includeEventSummary {
                    ensure(pdfFieldSectionHeight(fields: eventRows, width: contentWidth, columns: 2, valueFont: valueFont))
                    y = drawPDFFieldSection(
                        title: "EVENT AND INJURY SUMMARY".afLocalized,
                        fields: eventRows,
                        x: margin,
                        y: y,
                        width: contentWidth,
                        columns: 2,
                        accent: accent,
                        accentLight: accentLight,
                        border: border,
                        softFill: softFill,
                        sectionFont: sectionFont,
                        labelFont: labelFont,
                        valueFont: valueFont
                    ) + 8
                }

                let vitalRows = incident.vitalSigns.sorted { $0.recordedAt < $1.recordedAt }
                if options.includeVitalSigns {
                    ensure(pdfVitalsSectionHeight(records: vitalRows, width: contentWidth, tableFont: tableFont))
                    y = drawPDFVitalsSection(
                        records: vitalRows,
                        x: margin,
                        y: y,
                        width: contentWidth,
                        accent: accent,
                        accentLight: accentLight,
                        border: border,
                        sectionFont: sectionFont,
                        tableHeaderFont: tableHeaderFont,
                        tableFont: tableFont
                    ) + 8
                }

                let clinicalRows = [
                    PDFField(label: "Allergies".afLocalized, value: pdfKnown(profile.allergies)),
                    PDFField(label: "Medications".afLocalized, value: pdfKnown(profile.medications)),
                    PDFField(label: "Treatment".afLocalized, value: pdfKnown(profile.treatment)),
                    PDFField(label: "Medical history".afLocalized, value: pdfKnown(profile.medicalHistory)),
                    PDFField(label: "Notes".afLocalized, value: pdfRecorded(incident.patientNotes))
                ]
                if options.includeClinicalHistory {
                    ensure(pdfFieldSectionHeight(fields: clinicalRows, width: contentWidth, columns: 2, valueFont: valueFont))
                    y = drawPDFFieldSection(
                        title: "CLINICAL HISTORY".afLocalized,
                        fields: clinicalRows,
                        x: margin,
                        y: y,
                        width: contentWidth,
                        columns: 2,
                        accent: accent,
                        accentLight: accentLight,
                        border: border,
                        softFill: softFill,
                        sectionFont: sectionFont,
                        labelFont: labelFont,
                        valueFont: valueFont
                    ) + 8
                }

                let locationRows: [PDFField]
                if let location = incident.location {
                    locationRows = [
                        PDFField(label: "Coordinates".afLocalized, value: location.coordinateText),
                        PDFField(label: "Address".afLocalized, value: pdfRecorded(location.address)),
                        PDFField(label: "what3words", value: pdfRecorded(incident.what3Words))
                    ]
                } else {
                    locationRows = [PDFField(label: "Location".afLocalized, value: "Location not recorded.".afLocalized)]
                }
                if options.includeLocation {
                    ensure(pdfFieldSectionHeight(fields: locationRows, width: contentWidth, columns: 2, valueFont: valueFont))
                    y = drawPDFFieldSection(
                        title: "LOCATION".afLocalized,
                        fields: locationRows,
                        x: margin,
                        y: y,
                        width: contentWidth,
                        columns: 2,
                        accent: accent,
                        accentLight: accentLight,
                        border: border,
                        softFill: softFill,
                        sectionFont: sectionFont,
                        labelFont: labelFont,
                        valueFont: valueFont
                    ) + 8
                }

                let timelineRows = incident.timeline.sorted { $0.timestamp < $1.timestamp }
                if options.includeTimeline {
                    let timelineTitleHeight: CGFloat = 28
                    ensure(timelineTitleHeight + 30)
                    y = drawPDFSectionHeader(
                        "TIMELINE AND ACTIONS".afLocalized,
                        x: margin,
                        y: y,
                        width: contentWidth,
                        accent: accent,
                        sectionFont: sectionFont
                    )
                    if timelineRows.isEmpty {
                        let rowHeight: CGFloat = 24
                        ensure(rowHeight)
                        drawPDFTableCell("No timeline events recorded.".afLocalized, rect: CGRect(x: margin, y: y, width: contentWidth, height: rowHeight), font: tableFont, border: border)
                        y += rowHeight
                    } else {
                        for event in timelineRows {
                            let detail = event.detail.map(localizedDetail) ?? ""
                            let combined = detail.isEmpty ? AppStrings.display(event.title) : "\(AppStrings.display(event.title))\n\(detail)"
                            let rowHeight = max(28, pdfTextHeight(combined, width: contentWidth - 70, font: tableFont) + 12)
                            ensure(rowHeight)
                            drawPDFTableCell(handoverFormatter.string(from: event.timestamp), rect: CGRect(x: margin, y: y, width: 58, height: rowHeight), font: tableHeaderFont, border: border, fill: softFill)
                            drawPDFTableCell(combined, rect: CGRect(x: margin + 58, y: y, width: contentWidth - 58, height: rowHeight), font: tableFont, border: border)
                            y += rowHeight
                        }
                    }
                }

                if options.includeSignature && profile.includeResponderSignature {
                    ensure(pdfSignatureSectionHeight(profile: profile, width: contentWidth, valueFont: valueFont) + 8)
                    y += 8
                    y = drawPDFSignatureSection(profile: profile, x: margin, y: y, width: contentWidth, accent: accent, border: border, sectionFont: sectionFont, labelFont: labelFont, valueFont: valueFont)
                }

                if options.includeLegalFooter {
                    let legalRows = [
                        PDFField(label: "Notice".afLocalized, value: "AidFlow is a training, checklist, documentation, and first aid guidance tool. Review exported content before sharing. In an emergency in Australia, call 000 and follow emergency service instructions.".afLocalized)
                    ]
                    ensure(pdfFieldSectionHeight(fields: legalRows, width: contentWidth, columns: 1, valueFont: valueFont) + 8)
                    y += 8
                    y = drawPDFFieldSection(
                        title: "PRIVACY AND SAFETY NOTICE".afLocalized,
                        fields: legalRows,
                        x: margin,
                        y: y,
                        width: contentWidth,
                        columns: 1,
                        accent: accent,
                        accentLight: accentLight,
                        border: border,
                        softFill: softFill,
                        sectionFont: sectionFont,
                        labelFont: labelFont,
                        valueFont: valueFont
                    )
                }

                drawFooter()
            }
            return url
        } catch {
            return nil
        }
    }

    func handoverExportArtifacts(for incident: Incident, options: HandoverExportOptions = .full) -> HandoverExportArtifacts {
        HandoverExportArtifacts(
            documentURL: handoverDocumentURL(for: incident, options: options),
            pdfURL: handoverPDFURL(for: incident, options: options)
        )
    }

    func selectedIncidentsDocumentURL(for incidents: [Incident]) -> URL? {
        guard !incidents.isEmpty else { return nil }

        let text = incidents
            .map { generateHandover(for: $0) }
            .joined(separator: "\n\n------------------------------\n\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AidFlow-Selected-Incidents")
            .appendingPathExtension("txt")

        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    func generateHandover(for incident: Incident, options: HandoverExportOptions = .full) -> String {
        let timelineLines = incident.timeline.sorted { $0.timestamp < $1.timestamp }.map { event in
            let time = handoverFormatter.string(from: event.timestamp)
            if let detail = event.detail, !detail.isEmpty {
                return "\(time)  \(AppStrings.display(event.title))\n      \(localizedDetail(detail))"
            }
            return "\(time)  \(AppStrings.display(event.title))"
        }
        let vitalSignsLines = incident.vitalSigns
            .sorted { $0.recordedAt < $1.recordedAt }
            .map(vitalSignsHandoverLine)

        let notes = incident.patientNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteSection = notes.isEmpty ? "No extra patient notes recorded.".afLocalized : localizedDetail(notes)
        let profile = incident.patientProfile
        let displayName = [profile.firstName, profile.surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let patientName = displayName.isEmpty ? profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines) : displayName
        let patientAddress = [
            profile.patientUnit,
            profile.patientStreet,
            profile.patientSuburb,
            profile.patientState,
            profile.patientPostcode
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
        let allergies = knownOrNil(profile.allergies)
        let medications = knownOrNil(profile.medications)
        let treatment = knownOrNil(profile.treatment)
        let background = knownOrNil(profile.medicalHistory)
        let eventName = knownOrNil(profile.eventName)
        let eventLocation = knownOrNil(profile.eventLocation)
        let eventStartTime = knownOrNil(profile.eventStartTime)
        let eventHistory = knownOrNil(profile.eventHistory)
        let injury = knownOrNil(profile.injury)
        let injuryBodyPart = knownOrNil(profile.injuryBodyPart)
        let emergencyContactDetailName = profile.emergencyContactDetailName.trimmingCharacters(in: .whitespacesAndNewlines)
        let emergencyContactDetail = profile.emergencyContactDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        let emergencyContactName = profile.emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines)
        let emergencyContactPhone = profile.emergencyContactPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let legacyEmergencyContact = profile.emergencyContact.trimmingCharacters(in: .whitespacesAndNewlines)
        let emergencyContact = [
            emergencyContactDetailName.isEmpty ? emergencyContactName : emergencyContactDetailName,
            emergencyContactDetail.isEmpty ? (emergencyContactPhone.isEmpty ? legacyEmergencyContact : emergencyContactPhone) : emergencyContactDetail
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " - ")
        let includePatientIdentity = UserDefaults.standard.bool(forKey: "developerModeEnabled")
        let patientSummaryLines: [String]
        if includePatientIdentity {
            patientSummaryLines = [
                "\("Name".afLocalized): \(patientName.isEmpty ? "Not recorded".afLocalized : patientName)",
                "\("Date of birth".afLocalized): \(profile.dateOfBirth.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not recorded".afLocalized : profile.dateOfBirth)",
                "\("Age".afLocalized): \(profile.age.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not recorded".afLocalized : profile.age)",
                "\("Sex".afLocalized): \(profile.sex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not recorded".afLocalized : AppStrings.display(profile.sex))",
                "\("Patient contact".afLocalized): \(profile.patientContactDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not recorded".afLocalized : profile.patientContactDetail)",
                "\("Patient address".afLocalized): \(patientAddress.isEmpty ? "Not recorded".afLocalized : patientAddress)",
                "\("Emergency contact".afLocalized): \(emergencyContact.isEmpty ? "Not recorded".afLocalized : emergencyContact)"
            ]
        } else {
            patientSummaryLines = [
                "\("Age".afLocalized): \(profile.age.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not recorded".afLocalized : profile.age)",
                "\("Sex".afLocalized): \(profile.sex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not recorded".afLocalized : AppStrings.display(profile.sex))"
            ]
        }
        let signatureSection: String
        if options.includeSignature && profile.includeResponderSignature {
            let signatureName = profile.responderSignatureName.trimmingCharacters(in: .whitespacesAndNewlines)
            let signatureRank = profile.responderSignatureRank.trimmingCharacters(in: .whitespacesAndNewlines)
            let signatureDivision = profile.responderSignatureDivision.trimmingCharacters(in: .whitespacesAndNewlines)
            let signatureMemberID = profile.responderSignatureMemberID.trimmingCharacters(in: .whitespacesAndNewlines)
            var signatureLines = ["\("SIGNATURE".afLocalized)"]
            if !signatureName.isEmpty {
                signatureLines.append(signatureName)
            }
            if !signatureRank.isEmpty {
                signatureLines.append(AppStrings.text("Rank: %@", signatureRank))
            }
            if !signatureDivision.isEmpty {
                signatureLines.append("\("Division".afLocalized): \(signatureDivision)")
            }
            if !signatureMemberID.isEmpty {
                signatureLines.append("MID: \(signatureMemberID)")
            }
            signatureSection = signatureLines.count > 1 ? """

            \(signatureLines.joined(separator: "\n"))
            """ : ""
        } else {
            signatureSection = ""
        }
        let departure = incident.patientDeparture.trimmingCharacters(in: .whitespacesAndNewlines)
        let locationSection: String

        if let location = incident.location {
            let what3Words = incident.what3Words.trimmingCharacters(in: .whitespacesAndNewlines)
            locationSection = """
            \("Coordinates".afLocalized): \(location.coordinateText)
            \("Address".afLocalized): \(location.address)
            what3words: \(what3Words.isEmpty ? "Not recorded".afLocalized : what3Words)
            """
        } else {
            locationSection = "Location not recorded.".afLocalized
        }

        var sections = ["AIDFLOW HANDOVER REPORT".afLocalized]

        if options.includeCaseOverview {
            sections.append("""
            \("CASE OVERVIEW".afLocalized)
            \("Record type".afLocalized): \(AppStrings.display(incident.kind.rawValue))
            \("Started".afLocalized): \(DateFormatter.sceneDateTime.string(from: incident.startedAt))
            \("Status".afLocalized): \(AppStrings.display(incident.status.rawValue))
            \("Patient left via".afLocalized): \(departure.isEmpty ? "Not recorded".afLocalized : AppStrings.display(departure))
            """)
        }

        if options.includePatientSummary {
            sections.append("""
            \("PATIENT SUMMARY".afLocalized)
            \(patientSummaryLines.joined(separator: "\n"))
            """)
        }

        if options.includeEventSummary {
            sections.append("""
            \("EVENT AND INJURY SUMMARY".afLocalized)
            \("Event name".afLocalized): \(eventName)
            \("Event location".afLocalized): \(eventLocation)
            \("Event time".afLocalized): \(eventStartTime)
            \("What happened".afLocalized): \(eventHistory)
            \("Injuries / concerns".afLocalized): \(injury)
            \("Body part(s)".afLocalized): \(injuryBodyPart)
            """)
        }

        if options.includeClinicalHistory {
            sections.append("""
            \("CLINICAL HISTORY".afLocalized)
            \("Allergies".afLocalized): \(allergies)
            \("Medications".afLocalized): \(medications)
            \("Treatment".afLocalized): \(treatment)
            \("Medical history".afLocalized): \(background)
            \("Notes".afLocalized): \(noteSection)
            """)
        }

        if options.includeVitalSigns {
            sections.append("""
            \("VITAL SIGNS".afLocalized)
            \(vitalSignsLines.isEmpty ? "No vital signs recorded.".afLocalized : vitalSignsLines.joined(separator: "\n"))
            """)
        }

        if options.includeLocation {
            sections.append("""
            \("LOCATION".afLocalized)
            \(locationSection)
            """)
        }

        if options.includeTimeline {
            sections.append("""
            \("TIMELINE AND ACTIONS".afLocalized)
            \(timelineLines.isEmpty ? "No timeline events recorded.".afLocalized : timelineLines.joined(separator: "\n"))
            """)
        }

        if !signatureSection.isEmpty {
            sections.append(signatureSection.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        if options.includeLegalFooter {
            sections.append("""
            \("PRIVACY AND SAFETY NOTICE".afLocalized)
            \("AidFlow is a training, checklist, documentation, and first aid guidance tool. Review exported content before sharing. In an emergency in Australia, call 000 and follow emergency service instructions.".afLocalized)
            """)
        }

        return sections.joined(separator: "\n\n")
    }

    private func knownOrNil(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Nil known".afLocalized : AppStrings.display(trimmed)
    }

    private func localizedDetail(_ detail: String) -> String {
        detail
            .components(separatedBy: "\n")
            .map { line in
                if line.hasPrefix("Note: ") {
                    return "\("Note".afLocalized): \(line.dropFirst(6))"
                }
                if line.hasPrefix("Patient left via: ") {
                    return AppStrings.text("Patient left via: %@", AppStrings.display(String(line.dropFirst(18))))
                }
                return AppStrings.display(line)
            }
            .joined(separator: "\n")
    }

    private func vitalSignsHandoverLine(_ record: VitalSignsRecord) -> String {
        let parts = record.summaryParts
        let time = handoverFormatter.string(from: record.recordedAt)
        if parts.isEmpty {
            return "\(time)  \("Vital signs recorded".afLocalized)"
        }
        return "\(time)  \(parts.joined(separator: ", "))"
    }

    private func drawPDFHeader(
        in context: CGContext,
        pageRect: CGRect,
        margin: CGFloat,
        accent: UIColor,
        titleFont: UIFont,
        footerFont: UIFont,
        incident: Incident
    ) -> CGFloat {
        let headerRect = CGRect(x: margin, y: margin, width: pageRect.width - margin * 2, height: 58)
        context.setFillColor(accent.cgColor)
        context.fill(headerRect)

        drawPDFText(
            "AIDFLOW",
            in: CGRect(x: headerRect.minX + 14, y: headerRect.minY + 9, width: 120, height: 18),
            font: UIFont.boldSystemFont(ofSize: 12),
            color: .white,
            alignment: .left
        )
        drawPDFText(
            "First Aid Observation & Handover".afLocalized,
            in: CGRect(x: headerRect.minX + 14, y: headerRect.minY + 24, width: 310, height: 24),
            font: titleFont,
            color: .white,
            alignment: .left
        )

        let status = AppStrings.display(incident.status.rawValue).uppercased()
        drawPDFText(
            status,
            in: CGRect(x: headerRect.maxX - 156, y: headerRect.minY + 10, width: 140, height: 18),
            font: UIFont.boldSystemFont(ofSize: 10),
            color: .white,
            alignment: .right
        )
        drawPDFText(
            DateFormatter.sceneDateTime.string(from: incident.startedAt),
            in: CGRect(x: headerRect.maxX - 206, y: headerRect.minY + 30, width: 190, height: 14),
            font: footerFont,
            color: UIColor.white.withAlphaComponent(0.88),
            alignment: .right
        )

        return headerRect.maxY + 12
    }

    private func drawPDFFieldSection(
        title: String,
        fields: [PDFField],
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        columns: Int,
        accent: UIColor,
        accentLight: UIColor,
        border: UIColor,
        softFill: UIColor,
        sectionFont: UIFont,
        labelFont: UIFont,
        valueFont: UIFont
    ) -> CGFloat {
        var currentY = drawPDFSectionHeader(title, x: x, y: y, width: width, accent: accent, sectionFont: sectionFont)
        let columnCount = max(columns, 1)
        let cellWidth = width / CGFloat(columnCount)
        let rows = stride(from: 0, to: fields.count, by: columnCount).map { start in
            Array(fields[start..<min(start + columnCount, fields.count)])
        }

        for (rowIndex, rowFields) in rows.enumerated() {
            let rowHeight = rowFields.reduce(CGFloat(34)) { height, field in
                max(height, pdfTextHeight(field.value, width: cellWidth - 12, font: valueFont) + 22)
            }

            for column in 0..<columnCount {
                let rect = CGRect(x: x + CGFloat(column) * cellWidth, y: currentY, width: cellWidth, height: rowHeight)
                drawPDFBox(rect, fill: rowIndex.isMultiple(of: 2) ? softFill : .white, stroke: border)
                guard column < rowFields.count else { continue }

                let field = rowFields[column]
                drawPDFText(
                    field.label.uppercased(),
                    in: CGRect(x: rect.minX + 6, y: rect.minY + 5, width: rect.width - 12, height: 10),
                    font: labelFont,
                    color: accent,
                    alignment: .left
                )
                drawPDFText(
                    field.value,
                    in: CGRect(x: rect.minX + 6, y: rect.minY + 17, width: rect.width - 12, height: rect.height - 20),
                    font: valueFont,
                    color: UIColor(red: 0.07, green: 0.09, blue: 0.10, alpha: 1),
                    alignment: .left
                )
            }
            currentY += rowHeight
        }

        drawPDFBox(CGRect(x: x, y: y, width: width, height: currentY - y), fill: nil, stroke: border, lineWidth: 1.1)
        return currentY
    }

    private func pdfFieldSectionHeight(
        fields: [PDFField],
        width: CGFloat,
        columns: Int,
        valueFont: UIFont
    ) -> CGFloat {
        let columnCount = max(columns, 1)
        let cellWidth = width / CGFloat(columnCount)
        var height: CGFloat = 20
        var index = 0

        while index < fields.count {
            let rowFields = fields[index..<min(index + columnCount, fields.count)]
            let rowHeight = rowFields.reduce(CGFloat(34)) { currentHeight, field in
                max(currentHeight, pdfTextHeight(field.value, width: cellWidth - 12, font: valueFont) + 22)
            }
            height += rowHeight
            index += columnCount
        }

        return height
    }

    private func drawPDFVitalsSection(
        records: [VitalSignsRecord],
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        accent: UIColor,
        accentLight: UIColor,
        border: UIColor,
        sectionFont: UIFont,
        tableHeaderFont: UIFont,
        tableFont: UIFont
    ) -> CGFloat {
        var currentY = drawPDFSectionHeader("VITAL SIGNS".afLocalized, x: x, y: y, width: width, accent: accent, sectionFont: sectionFont)
        let columns: [(String, CGFloat)] = [
            ("Time".afLocalized, 42),
            ("HR", 34),
            ("RR", 34),
            ("SpO2", 38),
            ("BP", 54),
            ("Temp", 40),
            ("Pain", 38),
            ("AVPU", 50),
            ("GCS", 34),
            ("Notes".afLocalized, width - 364)
        ]

        var currentX = x
        for column in columns {
            drawPDFTableCell(
                AppStrings.display(column.0),
                rect: CGRect(x: currentX, y: currentY, width: column.1, height: 20),
                font: tableHeaderFont,
                border: border,
                fill: accentLight,
                color: accent,
                alignment: .center
            )
            currentX += column.1
        }
        currentY += 20

        if records.isEmpty {
            drawPDFTableCell(
                "No vital signs recorded.".afLocalized,
                rect: CGRect(x: x, y: currentY, width: width, height: 24),
                font: tableFont,
                border: border,
                alignment: .center
            )
            currentY += 24
        }

        for record in records {
            currentX = x
            let values = [
                handoverFormatter.string(from: record.recordedAt),
                record.heartRate,
                record.respiratoryRate,
                record.oxygenSaturation,
                pdfBloodPressure(record),
                record.temperature,
                record.painScore,
                AppStrings.display(record.avpu),
                record.gcsScore,
                pdfVitalsNotes(record)
            ]
            let rowHeight = max(24, pdfTextHeight(values.last ?? "", width: columns.last?.1 ?? 100, font: tableFont) + 10)

            for (index, column) in columns.enumerated() {
                drawPDFTableCell(
                    pdfRecorded(values[index]),
                    rect: CGRect(x: currentX, y: currentY, width: column.1, height: rowHeight),
                    font: tableFont,
                    border: border,
                    alignment: index == columns.count - 1 ? .left : .center
                )
                currentX += column.1
            }
            currentY += rowHeight
        }

        drawPDFBox(CGRect(x: x, y: y, width: width, height: currentY - y), fill: nil, stroke: border, lineWidth: 1.1)
        return currentY
    }

    private func pdfVitalsSectionHeight(records: [VitalSignsRecord], width: CGFloat, tableFont: UIFont) -> CGFloat {
        let notesWidth = max(width - 364, 80)
        var height: CGFloat = 20

        if records.isEmpty {
            return height + 24
        }

        for record in records {
            height += max(24, pdfTextHeight(pdfVitalsNotes(record), width: notesWidth, font: tableFont) + 10)
        }

        return height
    }

    private func drawPDFSignatureSection(
        profile: PatientProfile,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        accent: UIColor,
        border: UIColor,
        sectionFont: UIFont,
        labelFont: UIFont,
        valueFont: UIFont
    ) -> CGFloat {
        let fields = pdfSignatureFields(for: profile)
        let sectionBottom = drawPDFFieldSection(
            title: "SIGNATURE".afLocalized,
            fields: fields,
            x: x,
            y: y,
            width: width,
            columns: 4,
            accent: accent,
            accentLight: UIColor(red: 0.87, green: 0.96, blue: 0.93, alpha: 1),
            border: border,
            softFill: .white,
            sectionFont: sectionFont,
            labelFont: labelFont,
            valueFont: valueFont
        )
        let lineY = sectionBottom + 30
        drawPDFText("Responder signature".afLocalized, in: CGRect(x: x, y: lineY, width: width / 2 - 10, height: 10), font: labelFont, color: accent, alignment: .left)
        drawPDFText("Date / time".afLocalized, in: CGRect(x: x + width / 2 + 10, y: lineY, width: width / 2 - 10, height: 10), font: labelFont, color: accent, alignment: .left)
        drawPDFBox(CGRect(x: x, y: lineY - 18, width: width / 2 - 10, height: 1), fill: border, stroke: border)
        drawPDFBox(CGRect(x: x + width / 2 + 10, y: lineY - 18, width: width / 2 - 10, height: 1), fill: border, stroke: border)
        return lineY + 14
    }

    private func pdfSignatureFields(for profile: PatientProfile) -> [PDFField] {
        [
            PDFField(label: "Name".afLocalized, value: pdfRecorded(profile.responderSignatureName)),
            PDFField(label: "Rank".afLocalized, value: pdfRecorded(profile.responderSignatureRank)),
            PDFField(label: "Division".afLocalized, value: pdfRecorded(profile.responderSignatureDivision)),
            PDFField(label: "Member ID".afLocalized, value: pdfRecorded(profile.responderSignatureMemberID))
        ]
    }

    private func pdfSignatureSectionHeight(profile: PatientProfile, width: CGFloat, valueFont: UIFont) -> CGFloat {
        pdfFieldSectionHeight(fields: pdfSignatureFields(for: profile), width: width, columns: 4, valueFont: valueFont) + 44
    }

    private func drawPDFSectionHeader(
        _ title: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        accent: UIColor,
        sectionFont: UIFont
    ) -> CGFloat {
        let rect = CGRect(x: x, y: y, width: width, height: 20)
        drawPDFBox(rect, fill: accent, stroke: accent)
        drawPDFText(title.uppercased(), in: rect.insetBy(dx: 8, dy: 4), font: sectionFont, color: .white, alignment: .left)
        return rect.maxY
    }

    private func drawPDFTableCell(
        _ value: String,
        rect: CGRect,
        font: UIFont,
        border: UIColor,
        fill: UIColor? = nil,
        color: UIColor = UIColor(red: 0.07, green: 0.09, blue: 0.10, alpha: 1),
        alignment: NSTextAlignment = .left
    ) {
        drawPDFBox(rect, fill: fill, stroke: border)
        drawPDFText(value, in: rect.insetBy(dx: 4, dy: 5), font: font, color: color, alignment: alignment)
    }

    private func drawPDFBox(_ rect: CGRect, fill: UIColor?, stroke: UIColor, lineWidth: CGFloat = 0.7) {
        if let fill {
            fill.setFill()
            UIRectFill(rect)
        }
        stroke.setStroke()
        let path = UIBezierPath(rect: rect)
        path.lineWidth = lineWidth
        path.stroke()
    }

    private func drawPDFText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    }

    private func pdfTextHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let rect = text.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraph],
            context: nil
        )
        return rect.height.rounded(.up)
    }

    private func pdfPatientName(for profile: PatientProfile) -> String {
        let displayName = [profile.firstName, profile.surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return displayName.isEmpty ? profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines) : displayName
    }

    private func pdfPatientAddress(for profile: PatientProfile) -> String {
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

    private func pdfEmergencyContact(for profile: PatientProfile) -> String {
        [
            profile.emergencyContactDetailName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? profile.emergencyContactName : profile.emergencyContactDetailName,
            profile.emergencyContactDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? profile.emergencyContactPhone : profile.emergencyContactDetail
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " - ")
    }

    private func pdfBloodPressure(_ record: VitalSignsRecord) -> String {
        let systolic = record.systolicBP.trimmingCharacters(in: .whitespacesAndNewlines)
        let diastolic = record.diastolicBP.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !systolic.isEmpty || !diastolic.isEmpty else { return "" }
        return "\(systolic.isEmpty ? "-" : systolic)/\(diastolic.isEmpty ? "-" : diastolic)"
    }

    private func pdfVitalsNotes(_ record: VitalSignsRecord) -> String {
        var notes: [String] = []
        if let pupilAssessment = record.pupilAssessment {
            notes.append(pupilAssessment.summaryText)
        }
        let cleanNotes = record.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanNotes.isEmpty {
            notes.append(cleanNotes)
        }
        return notes.joined(separator: "\n")
    }

    private func pdfKnown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Nil known".afLocalized : AppStrings.display(trimmed)
    }

    private func pdfRecorded(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not recorded".afLocalized : AppStrings.display(trimmed)
    }

    private func saveDatabase() {
        guard hasLoadedDatabase, !isRestoringDatabase else { return }
        if isBatchingDatabaseChanges {
            needsDatabaseSaveAfterBatch = true
            return
        }

        let database = currentDatabaseSnapshot()
        guard database != lastQueuedDatabase else { return }

        lastQueuedDatabase = database
        pendingDatabaseSave?.cancel()

        let workItem = DispatchWorkItem { [weak self, databaseURL, database] in
            let didWrite = Self.write(database, to: databaseURL)
            DispatchQueue.main.async {
                guard let self else { return }
                if didWrite {
                    self.lastWrittenDatabase = database
                } else if self.lastQueuedDatabase == database {
                    self.lastQueuedDatabase = self.lastWrittenDatabase
                }
                if self.lastQueuedDatabase == database {
                    self.pendingDatabaseSave = nil
                }
            }
        }
        pendingDatabaseSave = workItem
        databaseQueue.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func currentDatabaseSnapshot() -> IncidentDatabase {
        IncidentDatabase(currentIncident: currentIncident, pastIncidents: pastIncidents, plannedEvents: plannedEvents)
    }

    @discardableResult
    private func write(_ database: IncidentDatabase) -> Bool {
        Self.write(database, to: databaseURL)
    }

    @discardableResult
    private static func write(_ database: IncidentDatabase, to databaseURL: URL) -> Bool {
        do {
            let data = try JSONEncoder.prettyAidFlow.encode(database)
            try data.write(to: databaseURL, options: [.atomic])
            return true
        } catch {
            return false
        }
    }

    private func sortPlannedEvents() {
        Self.sortPlannedEvents(&plannedEvents)
    }

    fileprivate static func sortPlannedEvents(_ events: inout [PlannedEvent]) {
        events.sort { left, right in
            if left.isUpcoming != right.isUpcoming {
                return left.isUpcoming && !right.isUpcoming
            }
            return left.isUpcoming ? left.startsAt < right.startsAt : left.startsAt > right.startsAt
        }
    }

    private func performDatabaseMutation(_ mutation: () -> Void) {
        let wasBatching = isBatchingDatabaseChanges
        isBatchingDatabaseChanges = true
        mutation()
        isBatchingDatabaseChanges = wasBatching

        guard !wasBatching, needsDatabaseSaveAfterBatch else { return }
        needsDatabaseSaveAfterBatch = false
        saveDatabase()
    }

    private static func readDatabase(from databaseURL: URL) -> IncidentDatabase? {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: databaseURL)
            return try JSONDecoder.aidFlow
                .decode(IncidentDatabase.self, from: data)
                .normalizedForStore()
        } catch {
            quarantineCorruptDatabase(at: databaseURL)
            return nil
        }
    }

    private static func quarantineCorruptDatabase(at databaseURL: URL) {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else { return }

        let stamp = ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupURL = databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent("incident-database-corrupt-\(stamp)-\(UUID().uuidString.prefix(8)).json")

        try? FileManager.default.moveItem(at: databaseURL, to: backupURL)
    }

    private func sortCurrentIncidentTimeline() {
        currentIncident?.timeline.sort { $0.timestamp < $1.timestamp }
    }

    private func updateVitalSignsTimelineEvent(from previousRecord: VitalSignsRecord?, to updatedRecord: VitalSignsRecord) {
        guard let previousRecord else {
            return
        }

        let index = currentIncident?.timeline.firstIndex { $0.sourceID == updatedRecord.id }
            ?? currentIncident?.timeline.firstIndex { vitalSignsTimelineFallbackMatches($0, record: previousRecord) }
        guard let index else { return }

        currentIncident?.timeline[index].sourceID = updatedRecord.id
        currentIncident?.timeline[index].timestamp = updatedRecord.recordedAt
        currentIncident?.timeline[index].title = vitalSignsTimelineTitle(for: updatedRecord)
        currentIncident?.timeline[index].detail = vitalSignsTimelineDetail(for: updatedRecord)
        sortCurrentIncidentTimeline()
    }

    private func deleteVitalSignsTimelineEvent(for record: VitalSignsRecord) {
        let hasLinkedTimelineEvent = currentIncident?.timeline.contains { $0.sourceID == record.id } ?? false
        if hasLinkedTimelineEvent {
            currentIncident?.timeline.removeAll { $0.sourceID == record.id }
            return
        }

        if let index = currentIncident?.timeline.firstIndex(where: { vitalSignsTimelineFallbackMatches($0, record: record) }) {
            currentIncident?.timeline.remove(at: index)
        }
    }

    private func vitalSignsTimelineTitle(for record: VitalSignsRecord) -> String {
        isPupilOnlyVitalSignsRecord(record) ? "Pupil reaction check recorded" : "Vital signs recorded"
    }

    private func vitalSignsTimelineDetail(for record: VitalSignsRecord) -> String? {
        if isPupilOnlyVitalSignsRecord(record), let pupilSummary = record.pupilAssessment?.summaryText {
            return pupilSummary
        }
        return record.timelineSummary
    }

    private func isPupilOnlyVitalSignsRecord(_ record: VitalSignsRecord) -> Bool {
        guard record.pupilAssessment != nil else { return false }
        return [
            record.heartRate,
            record.respiratoryRate,
            record.oxygenSaturation,
            record.systolicBP,
            record.diastolicBP,
            record.temperature,
            record.painScore,
            record.avpu,
            record.gcsScore
        ]
        .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func vitalSignsTimelineFallbackMatches(_ event: TimelineEvent, record: VitalSignsRecord) -> Bool {
        guard event.sourceID == nil else { return false }
        guard event.title == "Vital signs recorded" || event.title == "Pupil reaction check recorded" else { return false }
        return abs(event.timestamp.timeIntervalSince(record.recordedAt)) < 0.001
    }

    private func updateLiveActivity() {
        guard let currentIncident else { return }
        LiveActivityManager.shared.startOrUpdate(for: currentIncident)
    }
}

private struct IncidentDatabase: Codable, Equatable {
    var currentIncident: Incident?
    var pastIncidents: [Incident]
    var plannedEvents: [PlannedEvent]

    init(currentIncident: Incident?, pastIncidents: [Incident], plannedEvents: [PlannedEvent]) {
        self.currentIncident = currentIncident
        self.pastIncidents = pastIncidents
        self.plannedEvents = plannedEvents
    }

    private enum CodingKeys: String, CodingKey {
        case currentIncident
        case pastIncidents
        case plannedEvents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentIncident = try container.decodeIfPresent(Incident.self, forKey: .currentIncident)
        pastIncidents = try container.decodeIfPresent([Incident].self, forKey: .pastIncidents) ?? []
        plannedEvents = try container.decodeIfPresent([PlannedEvent].self, forKey: .plannedEvents) ?? []
    }
}

private extension IncidentDatabase {
    func normalizedForStore() -> IncidentDatabase {
        var database = self
        database.currentIncident = currentIncident?.normalizedForStore()

        let currentIncidentID = database.currentIncident?.id
        var seenIncidents = Set<UUID>()
        database.pastIncidents = pastIncidents
            .map { $0.normalizedForStore() }
            .filter { incident in
                guard incident.id != currentIncidentID else { return false }
                return seenIncidents.insert(incident.id).inserted
            }
            .sorted { $0.startedAt > $1.startedAt }

        var seenEvents = Set<UUID>()
        database.plannedEvents = plannedEvents.filter { event in
            seenEvents.insert(event.id).inserted
        }
        IncidentStore.sortPlannedEvents(&database.plannedEvents)
        return database
    }
}

private extension Incident {
    func normalizedForStore() -> Incident {
        var incident = self
        incident.arrivalStepIndex = min(max(arrivalStepIndex, 0), ArrivalFlow.steps.count)
        incident.vitalSigns.sort {
            if $0.recordedAt != $1.recordedAt {
                return $0.recordedAt < $1.recordedAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        incident.timeline.sort {
            if $0.timestamp != $1.timestamp {
                return $0.timestamp < $1.timestamp
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        return incident
    }
}

extension PatientProfile {
    mutating func applyPlannedEvent(_ event: PlannedEvent) {
        eventName = event.name
        eventLocation = event.location
        eventStartTime = DateFormatter.sceneDateTime.string(from: event.startsAt)
        if eventHistory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            eventHistory = event.notes
        }
    }
}

extension JSONEncoder {
    static let prettyAidFlow: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let aidFlow: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension DateFormatter {
    static let sceneTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let sceneDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let fileSafeDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()

    static let eventDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    static let eventMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()
}
