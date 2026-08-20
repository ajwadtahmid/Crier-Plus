import SwiftUI

struct ReminderRow: View {
    @Bindable var reminder: Reminder
    var schedulingPath: SchedulingPath = .notification
    var onToggleActive: (Bool) -> Void = { _ in }

    private var schedulingPathLabel: String {
        schedulingPath == .alarm ? "Rings as a system alarm" : "Rings as a notification"
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
                        onToggleActive(newValue)
                    }
                )
            )
            .labelsHidden()
            .tint(Color.appAccent)
        }
        .padding(Theme.Spacing.lg)
        .background(Color.appSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reminder.title), \(reminder.scheduleDescription()), \(schedulingPathLabel)")
    }
}

#Preview {
    ReminderRow(reminder: Reminder(title: "Take a walk", spokenMessage: "Time to take a walk!", scheduledTime: .now))
        .padding()
}
