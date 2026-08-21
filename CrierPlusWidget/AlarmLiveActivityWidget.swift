import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// Renders the alarm-path reminder's Live Activity — Lock Screen and Dynamic Island presence
/// while it's ringing or snoozed. `AlarmKitService.schedule` never calls `Activity.request`
/// itself; AlarmKit drives this activity's lifecycle entirely from the `AlarmAttributes` passed at
/// schedule time.
struct AlarmLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<EmptyAlarmMetadata>.self) { context in
            AlarmLiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.attributes.presentation.alert.title)
                            .font(.headline)
                        Text(statusText(for: context.state.mode))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(context.attributes.tintColor)
            }
        }
    }
}

private struct AlarmLiveActivityLockScreenView: View {
    let context: ActivityViewContext<AlarmAttributes<EmptyAlarmMetadata>>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "alarm.fill")
                .font(.title2)
                .foregroundStyle(context.attributes.tintColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.presentation.alert.title)
                    .font(.headline)
                Text(statusText(for: context.state.mode))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}

private func statusText(for mode: AlarmPresentationState.Mode) -> String {
    switch mode {
    case .alert:
        return "Ringing"
    case .countdown(let countdown):
        return "Snoozed until \(countdown.fireDate.formatted(date: .omitted, time: .shortened))"
    case .paused:
        return "Paused"
    @unknown default:
        return ""
    }
}
