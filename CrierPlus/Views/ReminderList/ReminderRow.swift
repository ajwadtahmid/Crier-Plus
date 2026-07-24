import SwiftUI

struct ReminderRow: View {
    @Bindable var reminder: Reminder

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

            Toggle("Active", isOn: $reminder.isActive)
                .labelsHidden()
                .tint(Color.appAccent)
        }
        .padding(Theme.Spacing.lg)
        .background(Color.appSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reminder.title), \(reminder.scheduleDescription())")
    }
}

#Preview {
    ReminderRow(reminder: Reminder(title: "Take a walk", spokenMessage: "Time to take a walk!", scheduledTime: .now))
        .padding()
}
