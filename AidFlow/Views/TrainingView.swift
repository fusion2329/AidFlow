import SwiftUI

struct TrainingView: View {
    @State private var didRevealContent = false

    private static let scenarios = [
        TrainingScenario(id: "cardiac-arrest", title: "Cardiac arrest", systemImage: "heart.fill", order: 1),
        TrainingScenario(id: "asthma-attack", title: "Asthma attack", systemImage: "lungs.fill", order: 2),
        TrainingScenario(id: "seizure", title: "Seizure", systemImage: "brain.head.profile", order: 3),
        TrainingScenario(id: "severe-bleeding", title: "Severe bleeding", systemImage: "drop.fill", order: 4),
        TrainingScenario(id: "anaphylaxis", title: "Anaphylaxis", systemImage: "allergens.fill", order: 5),
        TrainingScenario(id: "heat-illness", title: "Heat illness", systemImage: "thermometer.sun.fill", order: 6)
    ]

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Training Mode".afLocalized)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text("Guided scenario practice is being prepared.".afLocalized)
                            .foregroundStyle(Color.sceneMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .sceneEntrance(isVisible: didRevealContent, index: 0)

                    ForEach(Self.scenarios) { scenario in
                        TrainingScenarioCard(scenario: scenario)
                            .sceneEntrance(isVisible: didRevealContent, index: scenario.order)
                    }
                }
                .padding(24)
            }
        }
        .developerScreenID("510001", "TrainingView")
        .navigationTitle("Training".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            didRevealContent = true
        }
    }
}

private struct TrainingScenario: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let order: Int
}

private struct TrainingScenarioCard: View {
    let scenario: TrainingScenario

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: scenario.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.sceneAccent)
                .frame(width: 38, height: 38)
                .background(Color.sceneAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(scenario.title.afLocalized)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Preparing".afLocalized)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.sceneMuted)
                    .textCase(.uppercase)
            }

            Spacer(minLength: 12)

            Image(systemName: "lock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)
        }
        .padding(16)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
        .accessibilityElement(children: .combine)
    }
}
