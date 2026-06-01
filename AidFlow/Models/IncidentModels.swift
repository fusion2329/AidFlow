import Foundation

struct Incident: Identifiable, Codable, Equatable {
    let id: UUID
    let startedAt: Date
    var kind: IncidentKind
    var status: IncidentStatus
    var patientProfile: PatientProfile
    var patientNotes: String
    var patientDeparture: String
    var what3Words: String
    var location: IncidentLocation?
    var vitalSigns: [VitalSignsRecord]
    var timeline: [TimelineEvent]
    var arrivalStepIndex: Int

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        kind: IncidentKind = .sceneIncident,
        status: IncidentStatus = .active,
        patientProfile: PatientProfile = PatientProfile(),
        patientNotes: String = "",
        patientDeparture: String = "",
        what3Words: String = "",
        location: IncidentLocation? = nil,
        vitalSigns: [VitalSignsRecord] = [],
        timeline: [TimelineEvent] = [],
        arrivalStepIndex: Int = 0
    ) {
        self.id = id
        self.startedAt = startedAt
        self.kind = kind
        self.status = status
        self.patientProfile = patientProfile
        self.patientNotes = patientNotes
        self.patientDeparture = patientDeparture
        self.what3Words = what3Words
        self.location = location
        self.vitalSigns = vitalSigns
        self.timeline = timeline
        self.arrivalStepIndex = arrivalStepIndex
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case startedAt
        case kind
        case status
        case patientProfile
        case patientNotes
        case patientDeparture
        case what3Words
        case location
        case vitalSigns
        case timeline
        case arrivalStepIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        kind = try container.decodeIfPresent(IncidentKind.self, forKey: .kind) ?? .sceneIncident
        status = try container.decode(IncidentStatus.self, forKey: .status)
        patientProfile = try container.decodeIfPresent(PatientProfile.self, forKey: .patientProfile) ?? PatientProfile()
        patientNotes = try container.decodeIfPresent(String.self, forKey: .patientNotes) ?? ""
        patientDeparture = try container.decodeIfPresent(String.self, forKey: .patientDeparture) ?? ""
        what3Words = try container.decodeIfPresent(String.self, forKey: .what3Words) ?? ""
        location = try container.decodeIfPresent(IncidentLocation.self, forKey: .location)
        vitalSigns = try container.decodeIfPresent([VitalSignsRecord].self, forKey: .vitalSigns) ?? []
        timeline = try container.decodeIfPresent([TimelineEvent].self, forKey: .timeline) ?? []
        arrivalStepIndex = try container.decodeIfPresent(Int.self, forKey: .arrivalStepIndex) ?? 0
    }
}

extension Incident {
    var handoverExportCacheKey: String {
        let profile = patientProfile
        let locationKey: String
        if let location {
            locationKey = [
                String(location.latitude),
                String(location.longitude),
                location.address,
                location.nearbyStreet ?? "",
                String(location.capturedAt.timeIntervalSinceReferenceDate)
            ].joined(separator: "|")
        } else {
            locationKey = "no-location"
        }

        let profileKey = [
            profile.fullName,
            profile.firstName,
            profile.surname,
            profile.age,
            profile.dateOfBirth,
            profile.sex,
            profile.allergies,
            profile.medications,
            profile.treatment,
            profile.medicalHistory,
            profile.lastOralIntake,
            profile.eventsBefore,
            profile.emergencyContactName,
            profile.emergencyContactPhone,
            profile.emergencyContact,
            profile.patientUnit,
            profile.patientStreet,
            profile.patientSuburb,
            profile.patientState,
            profile.patientPostcode,
            profile.patientContactDetail,
            profile.emergencyContactDetailName,
            profile.emergencyContactDetail,
            profile.eventName,
            profile.eventLocation,
            profile.eventStartTime,
            profile.eventHistory,
            profile.injury,
            profile.injuryBodyPart,
            String(profile.includeResponderSignature),
            profile.responderSignatureName,
            profile.responderSignatureRank,
            profile.responderSignatureDivision,
            profile.responderSignatureMemberID
        ].joined(separator: "|")

        let vitalSignsKey = vitalSigns
            .sorted { $0.recordedAt < $1.recordedAt }
            .map { record in
                [
                    record.id.uuidString,
                    String(record.recordedAt.timeIntervalSinceReferenceDate),
                    record.heartRate,
                    record.respiratoryRate,
                    record.oxygenSaturation,
                    record.systolicBP,
                    record.diastolicBP,
                    record.temperature,
                    record.painScore,
                    record.avpu,
                    record.gcsScore,
                    record.pupilAssessment?.summaryText ?? "",
                    record.notes
                ].joined(separator: "|")
            }
            .joined(separator: "||")

        let timelineKey = timeline
            .sorted { $0.timestamp < $1.timestamp }
            .map { event in
                [
                    event.id.uuidString,
                    event.sourceID?.uuidString ?? "",
                    String(event.timestamp.timeIntervalSinceReferenceDate),
                    event.title,
                    event.detail ?? "",
                    event.category.rawValue
                ].joined(separator: "|")
            }
            .joined(separator: "||")

        return [
            id.uuidString,
            String(startedAt.timeIntervalSinceReferenceDate),
            kind.rawValue,
            status.rawValue,
            patientNotes,
            patientDeparture,
            what3Words,
            locationKey,
            profileKey,
            vitalSignsKey,
            timelineKey,
            String(arrivalStepIndex),
            AppLanguage.current.rawValue,
            String(UserDefaults.standard.bool(forKey: "developerModeEnabled"))
        ].joined(separator: "|||")
    }
}

struct VitalSignsRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var recordedAt: Date
    var heartRate: String
    var respiratoryRate: String
    var oxygenSaturation: String
    var systolicBP: String
    var diastolicBP: String
    var temperature: String
    var painScore: String
    var avpu: String
    var gcsScore: String
    var pupilAssessment: PupilAssessment?
    var notes: String

    init(
        id: UUID = UUID(),
        recordedAt: Date = Date(),
        heartRate: String = "",
        respiratoryRate: String = "",
        oxygenSaturation: String = "",
        systolicBP: String = "",
        diastolicBP: String = "",
        temperature: String = "",
        painScore: String = "",
        avpu: String = "",
        gcsScore: String = "",
        pupilAssessment: PupilAssessment? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.heartRate = heartRate
        self.respiratoryRate = respiratoryRate
        self.oxygenSaturation = oxygenSaturation
        self.systolicBP = systolicBP
        self.diastolicBP = diastolicBP
        self.temperature = temperature
        self.painScore = painScore
        self.avpu = avpu
        self.gcsScore = gcsScore
        self.pupilAssessment = pupilAssessment
        self.notes = notes
    }
}

enum PupilEyeSide: String, Codable, CaseIterable, Identifiable {
    case left = "Left"
    case right = "Right"

    var id: String { rawValue }
}

enum PupilReactionStatus: String, Codable, CaseIterable, Identifiable {
    case brisk = "Brisk"
    case sluggish = "Sluggish"
    case notObserved = "Not observed"
    case uncertain = "Uncertain"

    var id: String { rawValue }
}

enum PupilConfidence: String, Codable, CaseIterable, Identifiable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var id: String { rawValue }
}

enum PupilCaptureMode: String, Codable {
    case lidarAssistedRearTorch = "LiDAR-assisted rear torch"
    case rearTorchCameraOnly = "Rear torch camera only"
    case manualObservation = "Manual observation"
}

struct PupilEyeResult: Codable, Equatable {
    var side: PupilEyeSide
    var baselineDiameterPixels: Double?
    var minimumDiameterPixels: Double?
    var approximateDiameterMillimeters: Double?
    var constrictionPercent: Double?
    var latencySeconds: Double?
    var measurementQuality: Double?
    var qualityFlags: [String]?
    var usedNeuralSegmentation: Bool?
    var reactionStatus: PupilReactionStatus
    var confidence: PupilConfidence
    var distanceCentimeters: Double?
    var depthConfidence: PupilConfidence?
    var notes: String

    var summaryText: String {
        var parts = ["\(AppStrings.display(side.rawValue)): \(AppStrings.display(reactionStatus.rawValue))"]
        if let constrictionPercent {
            parts.append("\(Int(constrictionPercent.rounded()))%")
        }
        if let approximateDiameterMillimeters {
            parts.append(String(format: "%.1f mm", approximateDiameterMillimeters))
        }
        if let latencySeconds {
            parts.append(String(format: "latency %.2fs", latencySeconds))
        }
        parts.append("\(AppStrings.display(confidence.rawValue)) confidence")
        if let measurementQuality {
            parts.append("quality \(Int((measurementQuality * 100).rounded()))%")
        }
        return parts.joined(separator: " ")
    }
}

struct PupilAssessment: Identifiable, Codable, Equatable {
    var id: UUID
    var recordedAt: Date
    var captureMode: PupilCaptureMode
    var leftEye: PupilEyeResult?
    var rightEye: PupilEyeResult?
    var notes: String

    init(
        id: UUID = UUID(),
        recordedAt: Date = Date(),
        captureMode: PupilCaptureMode,
        leftEye: PupilEyeResult? = nil,
        rightEye: PupilEyeResult? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.captureMode = captureMode
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.notes = notes
    }

    var summaryText: String {
        let eyeSummaries = [leftEye, rightEye].compactMap { $0?.summaryText }
        if eyeSummaries.isEmpty {
            return "Pupils: Not recorded".afLocalized
        }

        var parts = ["\("Pupils".afLocalized): \(eyeSummaries.joined(separator: "; "))"]
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanNotes.isEmpty {
            parts.append("\("Notes".afLocalized): \(cleanNotes)")
        }
        return parts.joined(separator: " ")
    }
}

extension VitalSignsRecord {
    var summaryParts: [String] {
        var parts: [String] = []

        append("HR", heartRate, suffix: "bpm", to: &parts)
        append("RR", respiratoryRate, suffix: "/min", to: &parts)
        append("SpO2", oxygenSaturation, suffix: "%", to: &parts)

        let systolic = systolicBP.trimmingCharacters(in: .whitespacesAndNewlines)
        let diastolic = diastolicBP.trimmingCharacters(in: .whitespacesAndNewlines)
        if !systolic.isEmpty || !diastolic.isEmpty {
            parts.append("\(AppStrings.display("BP")) \(systolic.isEmpty ? "-" : systolic)/\(diastolic.isEmpty ? "-" : diastolic)")
        }

        append("Temp", temperature, suffix: "C", to: &parts)
        append("Pain", painScore, suffix: "/10", to: &parts)
        append("AVPU", avpu, suffix: "", to: &parts)
        append("GCS", gcsScore, suffix: "", to: &parts)
        if let pupilAssessment {
            parts.append(pupilAssessment.summaryText)
        }

        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanNotes.isEmpty {
            parts.append("\("Notes".afLocalized): \(cleanNotes)")
        }

        return parts
    }

    var timelineSummary: String? {
        let summary = summaryParts.joined(separator: ", ")
        return summary.isEmpty ? nil : summary
    }

    private func append(_ label: String, _ value: String, suffix: String, to parts: inout [String]) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if suffix.isEmpty || trimmed.hasSuffix(suffix) {
            parts.append("\(AppStrings.display(label)) \(trimmed)")
        } else {
            parts.append("\(AppStrings.display(label)) \(trimmed)\(suffix)")
        }
    }
}

struct PatientProfile: Codable, Equatable {
    var fullName: String
    var firstName: String
    var surname: String
    var age: String
    var dateOfBirth: String
    var sex: String
    var allergies: String
    var medications: String
    var treatment: String
    var medicalHistory: String
    var lastOralIntake: String
    var eventsBefore: String
    var emergencyContactName: String
    var emergencyContactPhone: String
    var emergencyContact: String
    var patientUnit: String
    var patientStreet: String
    var patientSuburb: String
    var patientState: String
    var patientPostcode: String
    var patientContactDetail: String
    var emergencyContactDetailName: String
    var emergencyContactDetail: String
    var eventName: String
    var eventLocation: String
    var eventStartTime: String
    var eventHistory: String
    var injury: String
    var injuryBodyPart: String
    var includeResponderSignature: Bool
    var responderSignatureName: String
    var responderSignatureRank: String
    var responderSignatureDivision: String
    var responderSignatureMemberID: String

    init(
        fullName: String = "",
        firstName: String = "",
        surname: String = "",
        age: String = "",
        dateOfBirth: String = "",
        sex: String = "",
        allergies: String = "",
        medications: String = "",
        treatment: String = "",
        medicalHistory: String = "",
        lastOralIntake: String = "",
        eventsBefore: String = "",
        emergencyContactName: String = "",
        emergencyContactPhone: String = "",
        emergencyContact: String = "",
        patientUnit: String = "",
        patientStreet: String = "",
        patientSuburb: String = "",
        patientState: String = "",
        patientPostcode: String = "",
        patientContactDetail: String = "",
        emergencyContactDetailName: String = "",
        emergencyContactDetail: String = "",
        eventName: String = "",
        eventLocation: String = "",
        eventStartTime: String = "",
        eventHistory: String = "",
        injury: String = "",
        injuryBodyPart: String = "",
        includeResponderSignature: Bool = false,
        responderSignatureName: String = "",
        responderSignatureRank: String = "",
        responderSignatureDivision: String = "",
        responderSignatureMemberID: String = ""
    ) {
        self.fullName = fullName
        self.firstName = firstName
        self.surname = surname
        self.age = age
        self.dateOfBirth = dateOfBirth
        self.sex = sex
        self.allergies = allergies
        self.medications = medications
        self.treatment = treatment
        self.medicalHistory = medicalHistory
        self.lastOralIntake = lastOralIntake
        self.eventsBefore = eventsBefore
        self.emergencyContactName = emergencyContactName
        self.emergencyContactPhone = emergencyContactPhone
        self.emergencyContact = emergencyContact
        self.patientUnit = patientUnit
        self.patientStreet = patientStreet
        self.patientSuburb = patientSuburb
        self.patientState = patientState
        self.patientPostcode = patientPostcode
        self.patientContactDetail = patientContactDetail
        self.emergencyContactDetailName = emergencyContactDetailName
        self.emergencyContactDetail = emergencyContactDetail
        self.eventName = eventName
        self.eventLocation = eventLocation
        self.eventStartTime = eventStartTime
        self.eventHistory = eventHistory
        self.injury = injury
        self.injuryBodyPart = injuryBodyPart
        self.includeResponderSignature = includeResponderSignature
        self.responderSignatureName = responderSignatureName
        self.responderSignatureRank = responderSignatureRank
        self.responderSignatureDivision = responderSignatureDivision
        self.responderSignatureMemberID = responderSignatureMemberID
    }

    mutating func removeIdentityDetails() {
        fullName = ""
        firstName = ""
        surname = ""
        dateOfBirth = ""
        emergencyContactName = ""
        emergencyContactPhone = ""
        emergencyContact = ""
        patientUnit = ""
        patientStreet = ""
        patientSuburb = ""
        patientState = ""
        patientPostcode = ""
        patientContactDetail = ""
        emergencyContactDetailName = ""
        emergencyContactDetail = ""
    }

    private enum CodingKeys: String, CodingKey {
        case fullName
        case firstName
        case surname
        case age
        case dateOfBirth
        case sex
        case allergies
        case medications
        case treatment
        case medicalHistory
        case lastOralIntake
        case eventsBefore
        case emergencyContactName
        case emergencyContactPhone
        case emergencyContact
        case patientUnit
        case patientStreet
        case patientSuburb
        case patientState
        case patientPostcode
        case patientContactDetail
        case emergencyContactDetailName
        case emergencyContactDetail
        case eventName
        case eventLocation
        case eventStartTime
        case eventHistory
        case injury
        case injuryBodyPart
        case includeResponderSignature
        case responderSignatureName
        case responderSignatureRank
        case responderSignatureDivision
        case responderSignatureMemberID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName) ?? ""
        surname = try container.decodeIfPresent(String.self, forKey: .surname) ?? ""
        age = try container.decodeIfPresent(String.self, forKey: .age) ?? ""
        dateOfBirth = try container.decodeIfPresent(String.self, forKey: .dateOfBirth) ?? ""
        sex = try container.decodeIfPresent(String.self, forKey: .sex) ?? ""
        allergies = try container.decodeIfPresent(String.self, forKey: .allergies) ?? ""
        medications = try container.decodeIfPresent(String.self, forKey: .medications) ?? ""
        treatment = try container.decodeIfPresent(String.self, forKey: .treatment) ?? ""
        medicalHistory = try container.decodeIfPresent(String.self, forKey: .medicalHistory) ?? ""
        lastOralIntake = try container.decodeIfPresent(String.self, forKey: .lastOralIntake) ?? ""
        eventsBefore = try container.decodeIfPresent(String.self, forKey: .eventsBefore) ?? ""
        emergencyContact = try container.decodeIfPresent(String.self, forKey: .emergencyContact) ?? ""
        emergencyContactName = try container.decodeIfPresent(String.self, forKey: .emergencyContactName) ?? ""
        emergencyContactPhone = try container.decodeIfPresent(String.self, forKey: .emergencyContactPhone) ?? emergencyContact
        patientUnit = try container.decodeIfPresent(String.self, forKey: .patientUnit) ?? ""
        patientStreet = try container.decodeIfPresent(String.self, forKey: .patientStreet) ?? ""
        patientSuburb = try container.decodeIfPresent(String.self, forKey: .patientSuburb) ?? ""
        patientState = try container.decodeIfPresent(String.self, forKey: .patientState) ?? ""
        patientPostcode = try container.decodeIfPresent(String.self, forKey: .patientPostcode) ?? ""
        patientContactDetail = try container.decodeIfPresent(String.self, forKey: .patientContactDetail) ?? ""
        emergencyContactDetailName = try container.decodeIfPresent(String.self, forKey: .emergencyContactDetailName) ?? emergencyContactName
        emergencyContactDetail = try container.decodeIfPresent(String.self, forKey: .emergencyContactDetail) ?? emergencyContactPhone
        eventName = try container.decodeIfPresent(String.self, forKey: .eventName) ?? ""
        eventLocation = try container.decodeIfPresent(String.self, forKey: .eventLocation) ?? ""
        eventStartTime = try container.decodeIfPresent(String.self, forKey: .eventStartTime) ?? ""
        eventHistory = try container.decodeIfPresent(String.self, forKey: .eventHistory) ?? ""
        injury = try container.decodeIfPresent(String.self, forKey: .injury) ?? ""
        injuryBodyPart = try container.decodeIfPresent(String.self, forKey: .injuryBodyPart) ?? ""
        includeResponderSignature = try container.decodeIfPresent(Bool.self, forKey: .includeResponderSignature) ?? false
        responderSignatureName = try container.decodeIfPresent(String.self, forKey: .responderSignatureName) ?? ""
        responderSignatureRank = try container.decodeIfPresent(String.self, forKey: .responderSignatureRank) ?? ""
        responderSignatureDivision = try container.decodeIfPresent(String.self, forKey: .responderSignatureDivision) ?? ""
        responderSignatureMemberID = try container.decodeIfPresent(String.self, forKey: .responderSignatureMemberID) ?? ""

        if firstName.isEmpty, surname.isEmpty, !fullName.isEmpty {
            let parts = fullName.split(separator: " ", maxSplits: 1).map(String.init)
            firstName = parts.first ?? ""
            surname = parts.count > 1 ? parts[1] : ""
        }
    }
}

struct PlannedEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var location: String
    var locationLatitude: Double?
    var locationLongitude: Double?
    var startsAt: Date
    var endsAt: Date?
    var notes: String
    var createdAt: Date
    var imageData: Data?
    var calendarEventIdentifier: String?

    init(
        id: UUID = UUID(),
        name: String = "",
        location: String = "",
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        startsAt: Date = Date(),
        endsAt: Date? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        imageData: Data? = nil,
        calendarEventIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.notes = notes
        self.createdAt = createdAt
        self.imageData = imageData
        self.calendarEventIdentifier = calendarEventIdentifier
    }

    var isUpcoming: Bool {
        let referenceDate = endsAt ?? startsAt
        return referenceDate >= Calendar.current.startOfDay(for: Date())
    }

    var timeSummary: String {
        if let endsAt {
            return "\(DateFormatter.sceneDateTime.string(from: startsAt)) - \(DateFormatter.sceneDateTime.string(from: endsAt))"
        }
        return DateFormatter.sceneDateTime.string(from: startsAt)
    }

    var profileTemplate: PatientProfile {
        PatientProfile(
            eventName: name,
            eventLocation: location,
            eventStartTime: DateFormatter.sceneDateTime.string(from: startsAt),
            eventHistory: notes
        )
    }

    var hasResolvedLocation: Bool {
        locationLatitude != nil && locationLongitude != nil
    }
}

enum EventTravelMode: String, CaseIterable, Identifiable {
    case driving = "Driving"
    case publicTransport = "Public Transport"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .driving:
            return "car.fill"
        case .publicTransport:
            return "tram.fill"
        }
    }
}

struct IncidentLocation: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var address: String
    var nearbyStreet: String?
    var capturedAt: Date

    var coordinateText: String {
        "\(String(format: "%.6f", latitude)), \(String(format: "%.6f", longitude))"
    }
}

enum IncidentKind: String, Codable, Equatable {
    case sceneIncident = "Scene Incident"
    case patientRecord = "Patient Record"
}

enum IncidentStatus: String, Codable, Equatable {
    case active = "Active"
    case handedOver = "Handed over"
    case record = "Record"
    case training = "Training"
}

struct TimelineEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var sourceID: UUID?
    var timestamp: Date
    var title: String
    var detail: String?
    var category: TimelineCategory

    init(
        id: UUID = UUID(),
        sourceID: UUID? = nil,
        timestamp: Date = Date(),
        title: String,
        detail: String? = nil,
        category: TimelineCategory = .observation
    ) {
        self.id = id
        self.sourceID = sourceID
        self.timestamp = timestamp
        self.title = title
        self.detail = detail
        self.category = category
    }
}

enum TimelineCategory: String, Codable, CaseIterable, Identifiable, Equatable {
    case arrival = "Arrival"
    case safety = "Safety"
    case assessment = "Assessment"
    case escalation = "Escalation"
    case treatment = "Treatment"
    case observation = "Observation"

    var id: String { rawValue }
}

struct ArrivalStep: Identifiable {
    let id: String
    let title: String
    let prompt: String
    let actionPrompt: String
    let category: TimelineCategory
    let yesLabel: String
    let yesEvent: String
    let noLabel: String
    let noEvent: String
    let unsureLabel: String
    let unsureEvent: String
    let yesAction: ArrivalAction?
    let noAction: ArrivalAction?
    let unsureAction: ArrivalAction?
    let helpTitle: String
    let helpSubtitle: String
    let helpItems: [ArrivalHelpItem]
    let warningText: String?

    init(
        id: String,
        title: String,
        prompt: String,
        actionPrompt: String,
        category: TimelineCategory,
        yesLabel: String = "Yes",
        yesEvent: String,
        noLabel: String = "No",
        noEvent: String,
        unsureLabel: String = "Unsure",
        unsureEvent: String = "",
        yesAction: ArrivalAction? = .continueFlow,
        noAction: ArrivalAction? = .continueFlow,
        unsureAction: ArrivalAction? = .continueFlow,
        helpTitle: String,
        helpSubtitle: String,
        helpItems: [ArrivalHelpItem],
        warningText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.actionPrompt = actionPrompt
        self.category = category
        self.yesLabel = yesLabel
        self.yesEvent = yesEvent
        self.noLabel = noLabel
        self.noEvent = noEvent
        self.unsureLabel = unsureLabel
        self.unsureEvent = unsureEvent
        self.yesAction = yesAction
        self.noAction = noAction
        self.unsureAction = unsureAction
        self.helpTitle = helpTitle
        self.helpSubtitle = helpSubtitle
        self.helpItems = helpItems
        self.warningText = warningText
    }
}

struct ArrivalHelpItem: Identifiable {
    let icon: String
    let title: String
    let detail: String

    var id: String { "\(icon)|\(title)|\(detail)" }
}

enum ArrivalAction {
    case continueFlow
    case callEmergency
    case sendForHelp
    case startCPR
    case openCPRCounter
    case recoveryPosition
    case getAED
    case checkAirway
    case checkBreathing
    case monitor
    case prepareHandover
    case openTimeline
}
