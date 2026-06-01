import PhotosUI
import SwiftUI

struct ProfileView: View {
    @AppStorage("userProfile.name") private var name = ""
    @AppStorage("userProfile.sex") private var sex = ""
    @AppStorage("userProfile.age") private var age = ""
    @AppStorage("userProfile.role") private var role = UserRole.responder.rawValue
    @AppStorage("userProfile.responderLevel") private var responderLevel = ResponderLevel.firstAider.rawValue
    @AppStorage("userProfile.memberSince") private var memberSince = ""
    @AppStorage("userProfile.email") private var email = ""
    @AppStorage("userProfile.phone") private var phone = ""
    @AppStorage("userProfile.avatarData") private var avatarData = ""
    @AppStorage("userProfile.signatureRank") private var signatureRank = ""
    @AppStorage("userProfile.signatureDivision") private var signatureDivision = ""
    @AppStorage("userProfile.signatureMemberID") private var signatureMemberID = ""
    @State private var isEditing = false
    @State private var firstName = ""
    @State private var surname = ""
    @State private var selectedAvatarItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(spacing: 16) {
                    profileCard
                    memberSignaturePanel
                }
                    .padding(20)
            }
        }
        .developerScreenID("410001", "ProfileView")
        .navigationTitle("Profile".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            normalizeStoredRole()
            loadNameParts()
        }
    }

    private var profileCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                avatar

                VStack(alignment: .leading, spacing: 5) {
                    if isEditing {
                        VStack(spacing: 8) {
                            TextField("First name".afLocalized, text: $firstName)
                                .textFieldStyle(.plain)
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .frame(height: 38)
                                .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)

                            TextField("Surname".afLocalized, text: $surname)
                                .textFieldStyle(.plain)
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .frame(height: 38)
                                .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
                        }
                    } else {
                        Text(displayName)
                            .font(.title.bold())
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }

                    Text("User Profile".afLocalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.sceneMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isEditing {
                            saveNameParts()
                            isEditing = false
                        } else {
                            loadNameParts()
                            isEditing = true
                        }
                    }
                } label: {
                    Text((isEditing ? "Done" : "Edit").afLocalized)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(Color.sceneAccent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(16)

            Divider()
                .overlay(Color.white.opacity(0.14))

            if isEditing {
                profileEditGrid
            } else {
                profileSummaryGrid
            }
        }
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
    }

    private var avatar: some View {
        PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.sceneAccent, Color.sceneSafe],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Text(initials)
                        .font(.title2.bold())
                        .foregroundStyle(.black)
                }

                if isEditing {
                    Image(systemName: "camera.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .frame(width: 24, height: 24)
                        .background(Color.sceneAccent, in: Circle())
                        .offset(x: 24, y: 24)
                }
            }
        }
        .frame(width: 74, height: 74)
        .overlay {
            Circle()
                .stroke(.white.opacity(0.42), lineWidth: 1)
        }
        .shadow(color: Color.sceneAccent.opacity(0.22), radius: 16, x: 0, y: 8)
        .disabled(!isEditing)
        .onChange(of: selectedAvatarItem) { newItem in
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                avatarData = data.base64EncodedString()
            }
        }
    }

    private var profileSummaryGrid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ProfileInfoCell(title: "Member since".afLocalized, value: memberSince)
                verticalDivider
                ProfileInfoCell(title: "Responder level".afLocalized, value: AppStrings.display(responderLevel))
            }

            horizontalDivider

            HStack(spacing: 0) {
                ProfileInfoCell(title: "Role".afLocalized, value: AppStrings.display(role))
                verticalDivider
                ProfileInfoCell(title: "Personal contact".afLocalized, value: personalContact)
            }
        }
    }

    private var profileEditGrid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ProfileEditCell(title: "Member since".afLocalized) {
                    TextField("MM/YYYY", text: $memberSince)
                }

                verticalDivider

                ProfileEditCell(title: "Responder level".afLocalized) {
                    Picker("Responder level".afLocalized, selection: $responderLevel) {
                        ForEach(ResponderLevel.allCases) { level in
                            Text(AppStrings.display(level.rawValue)).tag(level.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            horizontalDivider

            HStack(spacing: 0) {
                ProfileEditCell(title: "Role".afLocalized) {
                    Picker("Role".afLocalized, selection: $role) {
                        ForEach(UserRole.allCases) { role in
                            Text(AppStrings.display(role.rawValue)).tag(role.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }

                verticalDivider

                VStack(alignment: .leading, spacing: 8) {
                    ProfileEditCell(title: "Email".afLocalized) {
                        TextField("Email".afLocalized, text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    ProfileEditCell(title: "Phone".afLocalized) {
                        TextField("Phone".afLocalized, text: $phone)
                            .keyboardType(.phonePad)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var memberSignaturePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.sceneAccent.opacity(0.18))
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.sceneAccent)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Member Signature".afLocalized)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    Text("St John member only".afLocalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.sceneMuted)
                }

                Spacer()
            }

            if isEditing {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ProfileEditCell(title: "Rank".afLocalized) {
                            TextField("Rank".afLocalized, text: $signatureRank)
                        }

                        verticalDivider

                        ProfileEditCell(title: "Division".afLocalized) {
                            TextField("Division".afLocalized, text: $signatureDivision)
                        }
                    }

                    horizontalDivider

                    ProfileEditCell(title: "Member ID".afLocalized) {
                        TextField("Member ID".afLocalized, text: $signatureMemberID)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                }
            }

            if hasSignatureDetails {
                responderSignatureCard(
                    name: displayName == "Not set".afLocalized ? "" : displayName,
                    rank: signatureRank,
                    division: signatureDivision,
                    memberID: signatureMemberID
                )
            } else if !isEditing {
                Text("No member signature configured.".afLocalized)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.sceneAccent.opacity(0.18),
                            Color.sceneDanger.opacity(0.06),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
        }
        .overlay(alignment: .topTrailing) {
            AppIconMiniFlow()
                .stroke(
                    LinearGradient(
                        colors: [Color.sceneAccent.opacity(0.45), Color.sceneDanger.opacity(0.50)],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 130, height: 86)
                .padding(.trailing, 8)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.sceneAccent.opacity(0.36),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.sceneAccent.opacity(0.16), radius: 22, x: 0, y: 12)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(width: 1)
            .padding(.vertical, 12)
    }

    private var horizontalDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(height: 1)
            .padding(.horizontal, 12)
    }

    private var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not set".afLocalized : name
    }

    private func loadNameParts() {
        let parts = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1)
            .map(String.init)
        firstName = parts.first ?? ""
        surname = parts.count > 1 ? parts[1] : ""
    }

    private func saveNameParts() {
        name = [firstName, surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var initials: String {
        let parts = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }

        let value = String(parts).uppercased()
        return value.isEmpty ? "AF" : value
    }

    private var avatarImage: UIImage? {
        guard let data = Data(base64Encoded: avatarData) else { return nil }
        return UIImage(data: data)
    }

    private var personalContact: String {
        let parts = [email, phone]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "Not set".afLocalized : parts.joined(separator: "\n")
    }

    private var hasSignatureDetails: Bool {
        [signatureRank, signatureDivision, signatureMemberID]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func normalizeStoredRole() {
        switch role {
        case "First Aider", "EN - Enrolled Nurse", "RN - Registered Nurse", "EMT", "EMT - Emergency Medical Technician", "DOC", "Doc - Doctor", "Doctor":
            role = UserRole.responder.rawValue
        case "民众":
            role = UserRole.community.rawValue
        default:
            break
        }
    }
}

struct ResponderSignatureCard: View {
    let name: String
    let rank: String
    let division: String
    let memberID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayName)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if !clean(rank).isEmpty {
                Text(AppStrings.text("Rank: %@", clean(rank)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if !clean(division).isEmpty {
                Text(AppStrings.text("Division: %@", clean(division)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if !clean(memberID).isEmpty {
                Text("MID: \(clean(memberID))")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.sceneAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .overlay(alignment: .trailing) {
                    Image(systemName: "staroflife.fill")
                        .font(.system(size: 58, weight: .bold))
                        .foregroundStyle(Color.sceneAccent.opacity(0.10))
                        .padding(.trailing, 18)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.sceneAccent.opacity(0.34),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private var displayName: String {
        let trimmed = clean(name)
        return trimmed.isEmpty ? "Responder" : trimmed
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct AppIconMiniFlow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.82))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.58),
            control1: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.64),
            control2: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.minY + rect.height * 0.64)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.82, y: rect.minY + rect.height * 0.34),
            control1: CGPoint(x: rect.minX + rect.width * 0.54, y: rect.minY + rect.height * 0.36),
            control2: CGPoint(x: rect.minX + rect.width * 0.68, y: rect.minY + rect.height * 0.36)
        )
        return path
    }
}

func hasResponderSignatureContent(name: String, rank: String, division: String, memberID: String) -> Bool {
    [name, rank, division, memberID]
        .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

func responderSignatureCard(name: String, rank: String, division: String, memberID: String) -> some View {
    ResponderSignatureCard(name: name, rank: rank, division: division, memberID: memberID)
}

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    @AppStorage("developerModeEnabled") private var developerModeEnabled = false
    @AppStorage("routine.travelMode") private var travelMode = EventTravelMode.driving.rawValue

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    languageSection
                    routineSection
                    developerSection
                    acknowledgementSection
                    legalSection
                    versionSection
                }
                .padding(20)
            }
        }
        .developerScreenID("420001", "SettingsView")
        .navigationTitle("Settings".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Language".afLocalized)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .textCase(.uppercase)

            Picker("App language".afLocalized, selection: $appLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language.rawValue)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 48)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
        }
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
    }

    private var routineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Routine".afLocalized)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .textCase(.uppercase)

            Picker("Travel mode".afLocalized, selection: $travelMode) {
                ForEach(EventTravelMode.allCases) { mode in
                    Label(AppStrings.display(mode.rawValue), systemImage: mode.systemImage)
                        .tag(mode.rawValue)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 48)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
        }
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
    }

    private var developerSection: some View {
        Toggle(isOn: $developerModeEnabled) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Developer Mode".afLocalized)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.sceneAccent)
                    .textCase(.uppercase)

                Text("Show 6-digit screen IDs for easier feedback.".afLocalized)
                    .font(.footnote)
                    .foregroundStyle(Color.sceneMuted)
            }
        }
        .toggleStyle(.switch)
        .tint(Color.sceneAccent)
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
    }

    private var legalSection: some View {
        NavigationLink {
            LegalPrivacyView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.sceneAccent.opacity(0.16))
                    Image(systemName: "lock.shield.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.sceneAccent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Legal & Privacy".afLocalized)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Disclaimer, privacy protection, copyright, and data handling.".afLocalized)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.sceneMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.sceneMuted)
            }
        }
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
    }

    private var acknowledgementSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Acknowledgement of Country".afLocalized)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .textCase(.uppercase)

            Text("AidFlow acknowledges the Traditional Custodians of the land on which this app is used, and pays respect to Elders past and present.".afLocalized)
                .font(.footnote)
                .foregroundStyle(Color.sceneMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
    }

    private var versionSection: some View {
        HStack {
            Text("Version".afLocalized)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .textCase(.uppercase)

            Spacer()

            Text(appVersion)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)
        }
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct LegalPrivacyView: View {
    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    LegalTextSection(title: "Disclaimer".afLocalized, paragraphs: disclaimerParagraphs)
                    LegalTextSection(title: "Privacy Protection Policy".afLocalized, paragraphs: privacyParagraphs)
                    LegalTextSection(title: "Copyright".afLocalized, paragraphs: copyrightParagraphs)
                }
                .padding(20)
            }
        }
        .developerScreenID("420002", "LegalPrivacyView")
        .navigationTitle("Legal & Privacy".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Legal & Privacy".afLocalized)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Read the full AidFlow disclaimer and privacy protection policy before relying on the app during training or first aid documentation.".afLocalized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
    }

    private var disclaimerParagraphs: [String] {
        [
            "AidFlow is a training, checklist, documentation, and first aid guidance tool. It is not a medical device, does not provide diagnosis, and does not replace professional medical advice, emergency services, local clinical governance, or organisation procedures.",
            "In an emergency in Australia, call 000 immediately and follow instructions from emergency services. Do not delay urgent care, CPR, AED use, evacuation, or escalation because you are entering information into AidFlow.",
            "AidFlow content is general in nature and may not match every patient, environment, event, organisation, or jurisdiction. Users remain responsible for applying their own training, local protocols, scene safety judgement, and the instructions of qualified personnel.",
            "AidFlow records information entered by the user. The accuracy, completeness, and appropriateness of incident records, vital signs, timelines, patient details, handovers, exports, and shared reports depend on what the user enters and verifies.",
            "Location, map, travel, date, time, age, and generated report information may be unavailable, delayed, incomplete, or inaccurate. Always confirm critical information directly before using it for handover or decision-making.",
            "AidFlow may include training aids such as CPR rhythm support and GCS calculation. These are documentation and learning aids only. They must not be used to override formal training, emergency service instructions, AED prompts, or clinical judgement.",
            "By using AidFlow, you acknowledge that the app is provided as a prototype support tool and that you are responsible for using it safely, lawfully, and appropriately for your role and setting."
        ].map { $0.afLocalized }
    }

    private var privacyParagraphs: [String] {
        [
            "AidFlow is designed for local-first data handling. Profile details, member signature details, planned events, patient records, incident details, locations, timeline entries, vital signs, notes, handover text, PDF exports, language settings, developer mode settings, and avatar data are stored on this device unless you choose to share or export them.",
            "AidFlow does not operate its own server for incident records and does not intentionally upload patient or responder information to an AidFlow backend. Data may leave the device only when you use system features such as Share, export, maps, calendar integration, photos, backups, or other services controlled by iOS or by the apps you choose.",
            "If you share a handover, PDF, text report, selected incidents, screenshots, or any other exported content, the selected information is sent through the sharing method you choose. Review exported content carefully before sending it to another person or service.",
            "Location access is used to capture event or incident location details when requested. Map search, address lookup, navigation, or travel-time features may use Apple system services and are subject to the privacy practices and settings for those services.",
            "Photo access is used only when you choose an avatar or event image. Calendar access is used only for planned-event features that create, update, or remove calendar events. You can manage these permissions in iOS Settings.",
            "AidFlow stores sensitive first aid and patient-related information. Protect your device with a passcode or biometric lock, avoid entering unnecessary personal information, and delete records that you no longer need according to your organisation's retention rules.",
            "Deleting an incident or planned event in AidFlow removes it from the app's local database on this device. This may not remove copies that have already been exported, shared, backed up, screenshotted, printed, or saved by another app or service.",
            "AidFlow does not sell patient or responder data. Because the app is local-first, the main privacy risks are device access, user sharing choices, third-party apps selected through Share, and platform services such as backups, maps, calendar, and photos."
        ].map { $0.afLocalized }
    }

    private var copyrightParagraphs: [String] {
        [
            "Copyright © 2026 AidFlow. All rights reserved.",
            "AidFlow, its interface, generated layouts, and app-specific wording are provided for use within this prototype. Third-party names, services, emergency numbers, clinical terms, and organisation references remain the property of their respective owners."
        ].map { $0.afLocalized }
    }
}

struct FirstLaunchSafetyDisclaimerView: View {
    let onAccept: () -> Void

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    noticeSection

                    NavigationLink {
                        LegalPrivacyView()
                    } label: {
                        Label("Read full Legal & Privacy".afLocalized, systemImage: "lock.shield.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SceneSecondaryButtonStyle())
                    .accessibilityLabel("Read full Legal & Privacy".afLocalized)

                    Button {
                        onAccept()
                    } label: {
                        Label("I understand and agree".afLocalized, systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ScenePrimaryButtonStyle())
                    .accessibilityLabel("I understand and agree".afLocalized)
                }
                .padding(20)
            }
        }
        .developerScreenID("420003", "FirstLaunchSafetyDisclaimerView")
        .navigationTitle("Safety Notice".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "cross.case.fill")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .accessibilityHidden(true)

            Text("AidFlow Safety Notice".afLocalized)
                .font(.title.bold())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("Please read this before using AidFlow for training or first aid documentation.".afLocalized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.12)
    }

    private var noticeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SafetyNoticeRow(
                icon: "phone.fill",
                title: "Emergency first".afLocalized,
                detail: "In an emergency in Australia, call 000 immediately and follow emergency service instructions.".afLocalized
            )

            SafetyNoticeRow(
                icon: "stethoscope",
                title: "Not medical advice".afLocalized,
                detail: "AidFlow is a checklist, training, and documentation aid. It does not diagnose, treat, or replace professional advice or local procedures.".afLocalized
            )

            SafetyNoticeRow(
                icon: "doc.text.magnifyingglass",
                title: "Check before sharing".afLocalized,
                detail: "Records, vitals, locations, timelines, handovers, and PDFs depend on what you enter. Review exported content before sending it.".afLocalized
            )

            SafetyNoticeRow(
                icon: "lock.fill",
                title: "Local sensitive data".afLocalized,
                detail: "AidFlow stores incident and patient-related information on this device unless you choose to share or export it.".afLocalized
            )
        }
    }
}

private struct SafetyNoticeRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .frame(width: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
        .accessibilityElement(children: .combine)
    }
}

private struct LegalTextSection: View {
    let title: String
    let paragraphs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .textCase(.uppercase)

            ForEach(paragraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .font(.footnote)
                    .foregroundStyle(Color.sceneMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
    }
}

private struct ProfileInfoCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            Text(displayValue)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
    }

    private var displayValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not set".afLocalized : value
    }
}

private struct ProfileEditCell<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            content()
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
    }
}

private enum UserRole: String, CaseIterable, Identifiable {
    case responder = "Responder"
    case community = "Community Member"

    var id: String { rawValue }
}

private enum ResponderLevel: String, CaseIterable, Identifiable {
    case firstAider = "First Aider"
    case firstResponder = "First Responder"
    case emt = "EMT"
    case healthCareProfessional = "Health Care Professional"

    var id: String { rawValue }
}

private enum SexOption: String, CaseIterable, Identifiable {
    case female = "Female"
    case male = "Male"

    var id: String { rawValue }
}
