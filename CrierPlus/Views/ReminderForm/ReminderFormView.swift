import SwiftData
import SwiftUI

struct ReminderFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let existingReminder: Reminder?
    private let audioService = AudioGenerationService()

    @State private var title: String
    @State private var spokenMessage: String
    @State private var scheduledTime: Date
    @State private var repeatPattern: RepeatPattern
    @State private var repeatDays: Set<Int>
    @State private var isSaving = false
    @State private var validationErrors: [ReminderFormValidationError] = []
    @State private var saveErrorMessage: String?

    init(reminder: Reminder? = nil) {
        self.existingReminder = reminder
        _title = State(initialValue: reminder?.title ?? "")
        _spokenMessage = State(initialValue: reminder?.spokenMessage ?? "")
        _scheduledTime = State(initialValue: reminder?.scheduledTime ?? .now.addingTimeInterval(5 * 60))
        _repeatPattern = State(initialValue: reminder?.repeatPattern ?? .none)
        _repeatDays = State(initialValue: Set(reminder?.repeatDays ?? []))
    }

    private var isEditing: Bool { existingReminder != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder") {
                    TextField("Title", text: $title)
                    if validationErrors.contains(.titleRequired) {
                        Text("Title is required.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Color.appDestructive)
                    }
                }

                Section("Message") {
                    TextEditor(text: $spokenMessage)
                        .frame(minHeight: 80)
                    HStack {
                        Spacer()
                        Text("\(spokenMessage.count)/\(ReminderFormValidator.messageCharacterLimit)")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(
                                spokenMessage.count > ReminderFormValidator.messageCharacterLimit
                                    ? Color.appDestructive
                                    : Color.appTextSecondary
                            )
                    }
                    if validationErrors.contains(.messageTooLong) {
                        Text("Message must be \(ReminderFormValidator.messageCharacterLimit) characters or fewer.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Color.appDestructive)
                    }
                }

                Section("Schedule") {
                    DatePicker("Time", selection: $scheduledTime, displayedComponents: [.date, .hourAndMinute])
                    if validationErrors.contains(.scheduledTimeMustBeInFuture) {
                        Text("Choose a time that hasn't already passed.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Color.appDestructive)
                    }
                    Picker("Repeat", selection: $repeatPattern) {
                        ForEach(RepeatPattern.allCases, id: \.self) { pattern in
                            Text(pattern.displayName).tag(pattern)
                        }
                    }
                    if repeatPattern == .custom {
                        CustomDaySelector(selectedDays: $repeatDays)
                        if validationErrors.contains(.customRepeatRequiresADay) {
                            Text("Select at least one day.")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Color.appDestructive)
                        }
                    }
                }

                if let saveErrorMessage {
                    Section {
                        Text(saveErrorMessage)
                            .foregroundStyle(Color.appDestructive)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Reminder" : "New Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save", action: save)
                    }
                }
            }
        }
    }

    private func save() {
        let errors = ReminderFormValidator.validate(
            title: title,
            message: spokenMessage,
            scheduledTime: scheduledTime,
            repeatPattern: repeatPattern,
            repeatDays: Array(repeatDays)
        )
        validationErrors = errors
        guard errors.isEmpty else { return }

        isSaving = true
        Task {
            defer { isSaving = false }

            let reminder =
                existingReminder
                ?? Reminder(
                    title: title,
                    spokenMessage: spokenMessage,
                    scheduledTime: scheduledTime,
                    repeatPattern: repeatPattern,
                    repeatDays: Array(repeatDays)
                )
            if existingReminder != nil {
                reminder.title = title
                reminder.spokenMessage = spokenMessage
                reminder.scheduledTime = scheduledTime
                reminder.repeatPattern = repeatPattern
                reminder.repeatDays = Array(repeatDays)
            } else {
                modelContext.insert(reminder)
            }

            do {
                let fileURL = try await audioService.generateAudio(for: reminder.id, message: reminder.spokenMessage)
                reminder.audioFilePath = fileURL.lastPathComponent
                reminder.voiceIdentifier = UserDefaults.standard.string(forKey: AppStorageKeys.voiceIdentifier)
                dismiss()
            } catch {
                saveErrorMessage = error.localizedDescription
            }
        }
    }
}

#Preview("New") {
    ReminderFormView()
        .modelContainer(for: Reminder.self, inMemory: true)
}

#Preview("Edit") {
    ReminderFormView(
        reminder: Reminder(
            title: "Take a walk",
            spokenMessage: "Time to take a walk!",
            scheduledTime: .now,
            repeatPattern: .custom,
            repeatDays: [2, 4]
        )
    )
    .modelContainer(for: Reminder.self, inMemory: true)
}
