import SwiftData
import SwiftUI

struct AlarmRingView: View {
    let reminderID: UUID
    let path: SchedulingPath
    var onFinish: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var reminder: Reminder?
    @State private var isProcessing = false

    private let audioService = AudioGenerationService()
    private let actionHandler = AlarmActionHandler()

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                if let reminder {
                    Text(reminder.scheduledTime, style: .time)
                        .font(Theme.Typography.time)
                        .foregroundStyle(Color.appTextPrimary)
                    Text(reminder.title)
                        .font(Theme.Typography.title)
                        .foregroundStyle(Color.appTextPrimary)
                    Text(reminder.spokenMessage)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
            }

            Button(action: replay) {
                Label("Replay", systemImage: "arrow.clockwise")
                    .frame(minHeight: Theme.Layout.minimumTapTarget)
            }
            .buttonStyle(.bordered)
            .disabled(isProcessing || reminder == nil)

            Spacer()

            HStack(spacing: Theme.Spacing.lg) {
                Button("Snooze", action: snooze)
                    .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget)
                    .buttonStyle(.bordered)
                    .tint(Color.appAccent)

                Button("Dismiss", action: dismiss)
                    .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appDestructive)
            }
            .disabled(isProcessing || reminder == nil)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Color.appBackground)
        .onAppear(perform: loadReminder)
    }

    private func loadReminder() {
        var descriptor = FetchDescriptor<Reminder>(predicate: #Predicate { $0.id == reminderID })
        descriptor.fetchLimit = 1
        reminder = try? modelContext.fetch(descriptor).first
    }

    private func replay() {
        guard let reminder else { return }
        Task {
            try? await audioService.replay(for: reminder.id, message: reminder.spokenMessage)
        }
    }

    private func snooze() {
        isProcessing = true
        Task {
            defer { isProcessing = false }
            _ = try? await actionHandler.snooze(reminderID: reminderID, path: path)
            onFinish()
        }
    }

    private func dismiss() {
        isProcessing = true
        Task {
            defer { isProcessing = false }
            _ = try? await actionHandler.dismiss(reminderID: reminderID, path: path)
            onFinish()
        }
    }
}

#Preview {
    AlarmRingView(reminderID: UUID(), path: .notification, onFinish: {})
        .modelContainer(for: Reminder.self, inMemory: true)
}
