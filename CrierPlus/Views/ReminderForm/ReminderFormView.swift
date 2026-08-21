import SwiftData
import SwiftUI

struct ReminderFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let existingReminder: Reminder?
    private let audioService = AudioGenerationService()
    private let scheduler = ReminderScheduler()
    private let messageWriterService = MessageWriterService()
    private let aiAvailability = AIAvailability()

    @State private var title: String
    @State private var spokenMessage: String
    @State private var scheduledTime: Date
    @State private var repeatPattern: RepeatPattern
    @State private var repeatDays: Set<Int>
    @State private var isSaving = false
    @State private var isWritingMessage = false
    @State private var validationErrors: [ReminderFormValidationError] = []
    @State private var saveErrorMessage: String?
    @State private var soundWarningMessage: String?
    @State private var schedulingFallbackMessage: String?
    @State private var aiErrorMessage: String?

    init(reminder: Reminder? = nil) {
        self.existingReminder = reminder
        _title = State(initialValue: reminder?.title ?? "")
        _spokenMessage = State(initialValue: reminder?.spokenMessage ?? "")
        _scheduledTime = State(initialValue: reminder?.scheduledTime ?? .now.addingTimeInterval(5 * 60))
        _repeatPattern = State(initialValue: reminder?.repeatPattern ?? .none)
        _repeatDays = State(initialValue: Set(reminder?.repeatDays ?? []))
    }

    private var isEditing: Bool { existingReminder != nil }

    private var isAIAvailable: Bool {
        aiAvailability.status == .available
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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

                    if isWritingMessage {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Menu(isAIAvailable ? "Suggest Message" : "Use Template") {
                            ForEach(SuggestionTone.allCases, id: \.self) { tone in
                                Button(tone.displayName) { requestSuggestion(tone: tone) }
                            }
                        }
                        .disabled(trimmedTitle.isEmpty)

                        if !spokenMessage.isEmpty {
                            Menu("Rewrite Tone") {
                                ForEach(RewriteTone.allCases, id: \.self) { tone in
                                    Button(tone.displayName) { requestRewrite(tone: tone) }
                                }
                            }
                        }
                    }

                    if let aiErrorMessage {
                        Text(aiErrorMessage)
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

                if let soundWarningMessage {
                    Section {
                        Label(soundWarningMessage, systemImage: "exclamationmark.triangle")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                if let schedulingFallbackMessage {
                    Section {
                        Label(schedulingFallbackMessage, systemImage: "bell")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Color.appTextSecondary)
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
                    } else if soundWarningMessage != nil || schedulingFallbackMessage != nil {
                        Button("Done") { dismiss() }
                    } else {
                        Button("Save", action: save)
                    }
                }
            }
        }
    }

    private func requestSuggestion(tone: SuggestionTone) {
        aiErrorMessage = nil
        isWritingMessage = true
        Task {
            defer { isWritingMessage = false }
            do {
                let suggestions = try await messageWriterService.suggestions(forTitle: trimmedTitle)
                spokenMessage = suggestions.text(for: tone)
            } catch {
                aiErrorMessage = error.localizedDescription
            }
        }
    }

    private func requestRewrite(tone: RewriteTone) {
        aiErrorMessage = nil
        isWritingMessage = true
        Task {
            defer { isWritingMessage = false }
            do {
                spokenMessage = try await messageWriterService.rewrite(message: spokenMessage, tone: tone)
            } catch {
                aiErrorMessage = error.localizedDescription
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

                if reminder.isActive {
                    let result = try await scheduler.schedule(ReminderSchedulingPayload(reminder))
                    if case .fallbackTooLong(let duration) = result.soundWarning {
                        soundWarningMessage =
                            "This message is \(Int(duration.rounded()))s long — over the 30s limit for a "
                            + "custom sound, so it'll ring with the default sound instead."
                    }
                    if result.path == .notification {
                        schedulingFallbackMessage =
                            "Ringing as a notification instead of a system alarm, since Alarm access isn't on. "
                            + "Turn it on in Settings so this reminder can ring through Silent mode and Focus."
                    }
                } else {
                    await scheduler.cancel(for: reminder.id)
                }

                if soundWarningMessage == nil && schedulingFallbackMessage == nil {
                    dismiss()
                }
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
