import ActivityKit
import SwiftUI
import WidgetKit

@main
struct AidFlowLiveActivitiesBundle: WidgetBundle {
    var body: some Widget {
        AidFlowLiveActivityWidget()
    }
}

struct AidFlowLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AidFlowLiveActivityAttributes.self) { context in
            AidFlowLockScreenLiveActivityView(state: context.state)
                .activityBackgroundTint(Color(red: 0.04, green: 0.07, blue: 0.09))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "aidflow://arrival"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AidFlow")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AidFlowLiveActivityStyle.accent)
                        Text(context.state.cprState == nil ? context.state.stepTitle : "CPR Counter")
                            .font(.headline.weight(.bold))
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.cprState?.phaseValue ?? "\(context.state.stepNumber)/\(context.state.totalSteps)")
                            .font(.headline.monospacedDigit().weight(.bold))
                        Text(context.state.startedAt, style: .timer)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        if let cprState = context.state.cprState {
                            CPRLiveActivityCompactPanel(cprState: cprState)
                        } else {
                            Text(context.state.stepPrompt)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            Text(context.state.address)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.cprState == nil ? "cross.case.fill" : "heart.fill")
                    .foregroundStyle(AidFlowLiveActivityStyle.accent)
            } compactTrailing: {
                Text(context.state.cprState?.phaseValue ?? "\(context.state.stepNumber)/\(context.state.totalSteps)")
                    .font(.caption2.monospacedDigit().weight(.bold))
            } minimal: {
                Image(systemName: context.state.cprState == nil ? "cross.case.fill" : "heart.fill")
                    .foregroundStyle(AidFlowLiveActivityStyle.accent)
            }
            .widgetURL(URL(string: "aidflow://arrival"))
        }
    }
}

private struct AidFlowLockScreenLiveActivityView: View {
    let state: AidFlowLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AidFlowLiveActivityStyle.accent.opacity(0.22))
                    Image(systemName: state.cprState == nil ? "cross.case.fill" : "heart.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AidFlowLiveActivityStyle.accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.cprState == nil ? "AidFlow Arrival" : "AidFlow CPR")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AidFlowLiveActivityStyle.accent)
                    Text(state.cprState == nil ? state.stepTitle : "CPR Counter")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(state.cprState?.phaseValue ?? "\(state.stepNumber)/\(state.totalSteps)")
                        .font(.headline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                    Text(state.startedAt, style: .timer)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            if let cprState = state.cprState {
                CPRLiveActivityPanel(cprState: cprState)
            } else {
                Text(state.stepPrompt)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            if state.cprState == nil {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AidFlowLiveActivityStyle.accent)
                        .frame(width: 18, height: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.address)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(2)
                        if !state.coordinateText.isEmpty {
                            Text(state.coordinateText)
                                .font(.caption2.monospacedDigit().weight(.medium))
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(16)
    }
}

private struct CPRLiveActivityPanel: View {
    let cprState: AidFlowLiveActivityAttributes.CPRState

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: cprState.isBreathPhase ? "lungs.fill" : "heart.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AidFlowLiveActivityStyle.accent)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(cprState.phaseTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                    Text(cprState.isRunning ? "Running" : "Paused")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(1)
                }

                Spacer()

                Text(cprState.phaseValue)
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            HStack(spacing: 8) {
                CPRMetricChip(title: "Rate", value: "110/min")
                CPRMetricChip(title: "Cycle", value: "\(cprState.cycleCount)")
                CPRMetricChip(title: "Breaths", value: "2")
            }
        }
        .padding(10)
        .background(AidFlowLiveActivityStyle.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct CPRLiveActivityCompactPanel: View {
    let cprState: AidFlowLiveActivityAttributes.CPRState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: cprState.isBreathPhase ? "lungs.fill" : "heart.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AidFlowLiveActivityStyle.accent)

            Text(cprState.phaseTitle)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 6)

            Text(cprState.isRunning ? cprState.phaseValue : "Paused")
                .font(.subheadline.monospacedDigit().weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}

private struct CPRMetricChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.64))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private enum AidFlowLiveActivityStyle {
    static let accent = Color(red: 0.31, green: 0.93, blue: 0.74)
}
