import SwiftUI

struct ReminderRow: View {
    @Bindable var reminder: Reminder
    var schedulingPath: SchedulingPath = .notification
    var onToggleActive: (Bool) -> Void = { _ in }

    private var schedulingPathLabel: String {
        schedulingPath == .alarm ? "Rings as a system alarm" : "Rings as a notification"
    }

    private var formattedTime: String {
        reminder.scheduledTime.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(reminder.scheduledTime, style: .time)
                    .font(Theme.Typography.time)
                    .foregroundStyle(Color.appTextPrimary)
                Text(reminder.title)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Color.appTextPrimary)
                Text(reminder.scheduleDescription())
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Color.appTextSecondary)
            }
            // Grouped as one VoiceOver stop so the row reads naturally in one pass, but kept
            // separate from the icon/toggle below — an `.accessibilityElement(children: .combine)`
            // on the *whole* row would swallow the Toggle into the same element, making the
            // "Active" switch unreachable as its own control via VoiceOver.
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(formattedTime), \(reminder.title), \(reminder.scheduleDescription())")

            Spacer()

            Image(systemName: schedulingPath == .alarm ? "alarm.fill" : "bell.fill")
                .foregroundStyle(Color.appTextSecondary)
                .accessibilityLabel(schedulingPathLabel)

            Toggle(
                "Active",
                isOn: Binding(
                    get: { reminder.isActive },
                    set: { newValue in
                        reminder.isActive = newValue
                        Haptics.toggle()
                        onToggleActive(newValue)
                    }
                )
            )
            .labelsHidden()
            .tint(Color.appAccent)
            .accessibilityLabel("Active")
        }
        .padding(Theme.Spacing.lg)
        .background(Color.appSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.card))
    }
}

#Preview {
    ReminderRow(reminder: Reminder(title: "Take a walk", spokenMessage: "Time to take a walk!", scheduledTime: .now))
        .padding()
}
