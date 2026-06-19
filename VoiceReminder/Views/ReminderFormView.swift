import SwiftUI
import SwiftData

struct ReminderFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingReminder: Reminder?

    @AppStorage(AppStorageKey.username) private var username = ""

    @State private var title = ""
    @State private var spokenMessage = ""
    @State private var scheduledTime = Date()
    @State private var repeatPattern: RepeatPattern = .none
    @State private var repeatDays: Set<Int> = []
    @State private var selectedTone: MessageTone = .friendly

    @State private var isLoadingAI = false
    @State private var isSaving = false

    @State private var aiSuggestions: MessageSuggestions?
    @State private var aiErrorMessage: String?
    @State private var saveErrorMessage: String?
    @State private var showSavedToast = false

    private let aiAvailable: Bool
    private let audioService = AudioGenerationService()

    init(existingReminder: Reminder? = nil) {
        self.existingReminder = existingReminder
        self.aiAvailable = checkAIAvailability() == .ready
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    titleSection
                    messageSection
                    if aiAvailable { aiSection } else { useTemplateButton }
                    if !spokenMessage.isEmpty { toneSection }
                    previewSection
                    schedulingSection
                    saveSection
                }
                .padding(16)
            }
            .navigationTitle(existingReminder == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { loadExistingIfNeeded() }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title").font(.system(size: 16, weight: .semibold))
            TextField("Reminder title", text: $title)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color("SecondaryBackground"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("Border"), lineWidth: 1))
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Spoken Message").font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(spokenMessage.count)/200")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("TextSecondary"))
            }
            TextEditor(text: $spokenMessage)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color("SecondaryBackground"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("Border"), lineWidth: 1))
                .onChange(of: spokenMessage) { _, new in
                    if new.count > 200 { spokenMessage = String(new.prefix(200)) }
                }
        }
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                generateAISuggestions()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("AI Suggest")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isLoadingAI ? Color("Primary").opacity(0.5) : Color("Primary"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoadingAI || title.isEmpty)

            if isLoadingAI {
                HStack(spacing: 8) {
                    ProgressView().progressViewStyle(.circular)
                    Text("Getting suggestions...")
                        .font(.system(size: 14))
                        .foregroundStyle(Color("TextSecondary"))
                }
                .frame(maxWidth: .infinity)
            }

            if let suggestions = aiSuggestions {
                VStack(spacing: 8) {
                    suggestionCard(label: "Friendly",   text: suggestions.friendly)
                    suggestionCard(label: "Motivating", text: suggestions.motivating)
                    suggestionCard(label: "Direct",     text: suggestions.direct)
                }
            }

            if let error = aiErrorMessage {
                inlineErrorCard(message: error) {
                    aiErrorMessage = nil
                    spokenMessage = MessageWriterService.shared.templateFallback(
                        username: username, title: title)
                }
            }
        }
    }

    // Shown instead of aiSection when AI is unavailable
    private var useTemplateButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            spokenMessage = MessageWriterService.shared.templateFallback(
                username: username, title: title)
        } label: {
            Text("Use Template")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color("Primary"))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Primary"), lineWidth: 1))
        }
        .disabled(title.isEmpty)
    }

    private func suggestionCard(label: String, text: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            spokenMessage = text
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color("TextSecondary"))
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Color("TextPrimary"))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color("SecondaryBackground"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Border"), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tone").font(.system(size: 16, weight: .semibold))
            Picker("Tone", selection: $selectedTone) {
                ForEach(MessageTone.allCases, id: \.self) { tone in
                    Text(tone.displayName).tag(tone)
                }
            }
            .pickerStyle(.segmented)

            // Rewrite button is hidden when AI is unavailable — it's an AI action
            if aiAvailable {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    rewriteWithTone()
                } label: {
                    Text("Rewrite in \(selectedTone.displayName)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isLoadingAI ? Color("Primary").opacity(0.5) : Color("Primary"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                            isLoadingAI ? Color("Primary").opacity(0.5) : Color("Primary"),
                            lineWidth: 1))
                }
                .disabled(isLoadingAI)
            }
        }
    }

    private var previewSection: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            let text = spokenMessage.isEmpty
                ? MessageWriterService.shared.templateFallback(username: username, title: title)
                : spokenMessage
            audioService.speakPreview(text)
        } label: {
            HStack {
                Image(systemName: "speaker.wave.2")
                Text("Preview Voice")
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color("Primary"))
        }
        .disabled(title.isEmpty)
    }

    private var schedulingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule").font(.system(size: 16, weight: .semibold))

            DatePicker("Date & Time", selection: $scheduledTime,
                       displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)

            Picker("Repeat", selection: $repeatPattern) {
                ForEach(RepeatPattern.allCases, id: \.self) { pattern in
                    Text(pattern.displayName).tag(pattern)
                }
            }
            .pickerStyle(.menu)

            if repeatPattern == .custom { customDaysPicker }
        }
    }

    private var customDaysPicker: some View {
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { index in
                let selected = repeatDays.contains(index)
                Button {
                    if selected { repeatDays.remove(index) } else { repeatDays.insert(index) }
                } label: {
                    Text(days[index - 1])
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected ? .white : Color("Primary"))
                        .frame(width: 36, height: 36)
                        .background(selected ? Color("Primary") : Color.clear)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color("Primary"), lineWidth: 1))
                }
            }
        }
    }

    private var saveSection: some View {
        VStack(spacing: 8) {
            Button { save() } label: {
                HStack {
                    if isSaving {
                        ProgressView().progressViewStyle(.circular).tint(.white)
                        Text("Saving...")
                    } else {
                        Text("Save Reminder")
                    }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(title.isEmpty ? Color("Primary").opacity(0.5) : Color("Primary"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(title.isEmpty || isSaving)

            if let error = saveErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color("Destructive"))
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(Color("TextPrimary"))
                    Spacer()
                    Button("Retry") { save() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color("Primary"))
                }
                .padding(12)
                .background(Color("Destructive").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if showSavedToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color("Accent"))
                    Text("Reminder saved").font(.system(size: 14))
                }
                .transition(.opacity)
            }
        }
    }

    private func inlineErrorCard(message: String, useTemplate: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message).font(.system(size: 14)).foregroundStyle(.white)
            Button("Use Template", action: useTemplate)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("Destructive"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func loadExistingIfNeeded() {
        guard let r = existingReminder else { return }
        title        = r.title
        spokenMessage = r.spokenMessage
        scheduledTime = r.scheduledTime
        repeatPattern = r.repeatPattern
        repeatDays    = Set(r.repeatDays)
    }

    private func generateAISuggestions() {
        isLoadingAI   = true
        aiSuggestions = nil
        aiErrorMessage = nil
        Task {
            do {
                let result = try await MessageWriterService.shared.generateSuggestions(
                    title: title, username: username)
                await MainActor.run {
                    aiSuggestions = result
                    isLoadingAI   = false
                }
            } catch {
                await MainActor.run {
                    aiErrorMessage = "AI suggestion failed. Use the template instead."
                    isLoadingAI    = false
                }
            }
        }
    }

    private func rewriteWithTone() {
        isLoadingAI    = true
        aiErrorMessage = nil
        Task {
            do {
                let result = try await MessageWriterService.shared.rewrite(
                    message: spokenMessage, tone: selectedTone)
                await MainActor.run {
                    spokenMessage = result
                    isLoadingAI   = false
                }
            } catch {
                await MainActor.run {
                    aiErrorMessage = "Tone rewrite failed."
                    isLoadingAI    = false
                }
            }
        }
    }

    private func save() {
        isSaving          = true
        saveErrorMessage  = nil

        // Capture old audio path before any mutations
        let oldAudioPath = existingReminder?.audioFilePath

        Task {
            do {
                let message = spokenMessage.isEmpty
                    ? MessageWriterService.shared.templateFallback(username: username, title: title)
                    : spokenMessage

                let reminder = existingReminder ?? Reminder()

                // Cancel old notification and delete old audio before rescheduling
                if existingReminder != nil {
                    NotificationService.shared.cancel(reminder.id)
                    audioService.deleteAudio(at: oldAudioPath)
                }

                reminder.title         = title
                reminder.spokenMessage = message
                reminder.scheduledTime = scheduledTime
                reminder.repeatPattern = repeatPattern
                reminder.repeatDays    = Array(repeatDays)

                if existingReminder == nil { modelContext.insert(reminder) }

                let audioURL = try await audioService.generateAudio(for: reminder, message: message)
                reminder.audioFilePath = audioURL.path

                try await NotificationService.shared.schedule(reminder)

                UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                await MainActor.run {
                    isSaving = false
                    withAnimation { showSavedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showSavedToast = false }
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving         = false
                    saveErrorMessage = "Save failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
