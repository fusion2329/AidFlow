import MapKit
import SwiftUI

extension Color {
    static let sceneBackground = Color(red: 0.03, green: 0.05, blue: 0.06)
    static let scenePanel = Color(red: 0.12, green: 0.16, blue: 0.18)
    static let sceneMuted = Color(red: 0.68, green: 0.74, blue: 0.76)
    static let sceneAccent = Color(red: 0.35, green: 0.86, blue: 0.74)
    static let sceneSafe = Color(red: 0.35, green: 0.86, blue: 0.47)
    static let sceneDanger = Color(red: 1.00, green: 0.34, blue: 0.30)
    static let sceneWarning = Color(red: 1.00, green: 0.75, blue: 0.28)
    static let sceneGlassStroke = Color.white.opacity(0.22)
}

struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.05),
                    Color(red: 0.04, green: 0.10, blue: 0.11),
                    Color(red: 0.02, green: 0.05, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.sceneAccent.opacity(0.24),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 360
            )

            RadialGradient(
                colors: [
                    Color.sceneDanger.opacity(0.12),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

struct LiquidGlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 8
    var tint: Color = .white
    var opacity: Double = 0.12

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(opacity))
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.34),
                                Color.sceneAccent.opacity(0.18),
                                .white.opacity(0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.28), radius: 20, x: 0, y: 14)
    }
}

private enum SceneMotion {
    static let press = Animation.spring(response: 0.26, dampingFraction: 0.82)
    static let reveal = Animation.spring(response: 0.46, dampingFraction: 0.88)
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 8, tint: Color = .white, opacity: Double = 0.12) -> some View {
        modifier(LiquidGlassPanel(cornerRadius: cornerRadius, tint: tint, opacity: opacity))
    }

    func sceneEntrance(isVisible: Bool, index: Int = 0) -> some View {
        modifier(SceneEntranceModifier(isVisible: isVisible, index: index))
    }

    func developerScreenID(_ code: String, _ title: String) -> some View {
        modifier(DeveloperScreenID(code: code, title: title))
    }
}

private struct SceneEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isVisible: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: reduceMotion || isVisible ? 0 : 12)
            .animation(
                reduceMotion ? nil : SceneMotion.reveal.delay(Double(index) * 0.035),
                value: isVisible
            )
    }
}

private struct DeveloperScreenID: ViewModifier {
    @AppStorage("developerModeEnabled") private var developerModeEnabled = false
    let code: String
    let title: String

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, alignment: .trailing, spacing: 0) {
            if developerModeEnabled {
                Text("\(code) · \(title)")
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(.black.opacity(0.78))
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Color.sceneAccent.opacity(0.86), in: Capsule())
                    .padding(.trailing, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

struct SceneEmptyState: View {
    let title: String
    let systemImage: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.sceneAccent)
                .frame(width: 68, height: 68)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.12)

            Text(title)
                .font(.headline.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
    }
}

struct ScenePrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundStyle(.black)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.sceneAccent.opacity(configuration.isPressed ? 0.72 : 1),
                                Color.sceneSafe.opacity(configuration.isPressed ? 0.58 : 0.86)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.035 : 0)
            .shadow(
                color: Color.sceneAccent.opacity(configuration.isPressed ? 0.14 : 0.25),
                radius: configuration.isPressed ? 8 : 16,
                x: 0,
                y: configuration.isPressed ? 4 : 8
            )
            .animation(reduceMotion ? nil : SceneMotion.press, value: configuration.isPressed)
    }
}

struct SceneSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .liquidGlass(tint: Color.sceneAccent, opacity: configuration.isPressed ? 0.08 : 0.14)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.025 : 0)
            .animation(reduceMotion ? nil : SceneMotion.press, value: configuration.isPressed)
    }
}

struct SceneUtilityButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .liquidGlass(tint: Color.sceneAccent, opacity: configuration.isPressed ? 0.05 : 0.10)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.025 : 0)
            .animation(reduceMotion ? nil : SceneMotion.press, value: configuration.isPressed)
    }
}

struct SceneCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.025 : 0)
            .animation(reduceMotion ? nil : SceneMotion.press, value: configuration.isPressed)
    }
}

struct MapAddressField: View {
    let title: String
    @Binding var text: String
    var onResolve: ((ResolvedMapAddress) -> Void)? = nil
    @Environment(\.openURL) private var openURL
    @StateObject private var searcher = MapAddressSearcher()
    @State private var resolvedAddress: ResolvedMapAddress?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            TextField("Search address or place".afLocalized, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .focused($isFocused)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
                .onChange(of: text) { newValue in
                    searcher.query = newValue
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines) != resolvedAddress?.displayText {
                        resolvedAddress = nil
                    }
                }
                .onSubmit {
                    resolveTypedAddress()
                }

            if isFocused, !searcher.suggestions.isEmpty {
                VStack(spacing: 6) {
                    ForEach(searcher.suggestions.prefix(5), id: \.self) { suggestion in
                        Button {
                            selectSuggestion(suggestion)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(Color.sceneAccent)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.sceneMuted)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()
                            }
                            .padding(10)
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .liquidGlass(tint: Color.sceneAccent, opacity: 0.07)
                        }
                        .buttonStyle(SceneCardButtonStyle())
                    }
                }
            }

            if let resolvedAddress {
                MapAddressPreview(address: resolvedAddress) {
                    openMap(for: resolvedAddress)
                }
            }
        }
        .onAppear {
            searcher.query = text
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, resolvedAddress == nil {
                resolveTypedAddress()
            }
        }
    }

    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        isFocused = false
        let display = [suggestion.title, suggestion.subtitle]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ", ")
        text = display

        Task {
            if let resolved = await searcher.resolve(suggestion: suggestion, fallback: display) {
                await MainActor.run {
                    text = resolved.displayText
                    resolvedAddress = resolved
                    onResolve?(resolved)
                }
            }
        }
    }

    private func resolveTypedAddress() {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            resolvedAddress = nil
            return
        }

        Task {
            if let resolved = await searcher.resolve(query: query) {
                await MainActor.run {
                    text = resolved.displayText
                    resolvedAddress = resolved
                    onResolve?(resolved)
                }
            }
        }
    }

    private func openMap(for address: ResolvedMapAddress) {
        let encodedName = address.displayText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?ll=\(address.coordinate.latitude),\(address.coordinate.longitude)&q=\(encodedName)") {
            openURL(url)
        }
    }
}

private struct MapAddressPreview: View {
    let address: ResolvedMapAddress
    let openMap: () -> Void
    @State private var region: MKCoordinateRegion

    init(address: ResolvedMapAddress, openMap: @escaping () -> Void) {
        self.address = address
        self.openMap = openMap
        _region = State(
            initialValue: MKCoordinateRegion(
                center: address.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }

    var body: some View {
        Button {
            openMap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                mapPreview
                .allowsHitTesting(false)
                .frame(height: 118)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "map.fill")
                        .foregroundStyle(Color.sceneAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(address.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(address.subtitle.isEmpty ? address.displayText : address.subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.sceneMuted)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(Color.sceneMuted)
                }
            }
            .padding(10)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
        }
        .buttonStyle(SceneCardButtonStyle())
        .accessibilityLabel("Open in Maps".afLocalized)
    }

    @ViewBuilder
    private var mapPreview: some View {
        if #available(iOS 17.0, *) {
            Map(initialPosition: .region(region)) {
                Marker(address.title, coordinate: address.coordinate)
                    .tint(Color.sceneAccent)
            }
        } else {
            Map(
                coordinateRegion: $region,
                annotationItems: [MapAddressAnnotation(address: address)]
            ) { annotation in
                MapMarker(coordinate: annotation.coordinate, tint: Color.sceneAccent)
            }
        }
    }
}

private struct MapAddressAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D

    init(address: ResolvedMapAddress) {
        coordinate = address.coordinate
        id = "\(address.coordinate.latitude),\(address.coordinate.longitude),\(address.displayText)"
    }
}

struct ResolvedMapAddress: Equatable {
    let title: String
    let subtitle: String
    let displayText: String
    let coordinate: CLLocationCoordinate2D
    let streetNumber: String
    let streetName: String
    let suburb: String
    let state: String
    let postcode: String

    var streetLine: String {
        [streetNumber, streetName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func == (lhs: ResolvedMapAddress, rhs: ResolvedMapAddress) -> Bool {
        lhs.displayText == rhs.displayText &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

private final class MapAddressSearcher: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet {
            updateCompleterQuery()
        }
    }
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093),
            span: MKCoordinateSpan(latitudeDelta: 1.2, longitudeDelta: 1.2)
        )
    }

    private func updateCompleterQuery() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard completer.queryFragment != trimmedQuery else { return }

        if trimmedQuery.isEmpty {
            suggestions = []
        }
        completer.queryFragment = trimmedQuery
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.suggestions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.suggestions = []
        }
    }

    func resolve(suggestion: MKLocalSearchCompletion, fallback: String) async -> ResolvedMapAddress? {
        let request = MKLocalSearch.Request(completion: suggestion)
        return await resolve(request: request, fallback: fallback)
    }

    func resolve(query: String) async -> ResolvedMapAddress? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = completer.region
        return await resolve(request: request, fallback: query)
    }

    private func resolve(request: MKLocalSearch.Request, fallback: String) async -> ResolvedMapAddress? {
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else {
            return nil
        }

        let placemark = item.placemark
        let title = item.name ?? fallback
        let subtitle = [
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ]
        .compactMap { $0 }
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: ", ")
        let display = [title, subtitle]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ", ")

        return ResolvedMapAddress(
            title: title,
            subtitle: subtitle,
            displayText: display.isEmpty ? fallback : display,
            coordinate: placemark.coordinate,
            streetNumber: placemark.subThoroughfare ?? "",
            streetName: placemark.thoroughfare ?? "",
            suburb: placemark.locality ?? placemark.subLocality ?? "",
            state: placemark.administrativeArea ?? "",
            postcode: placemark.postalCode ?? ""
        )
    }
}
