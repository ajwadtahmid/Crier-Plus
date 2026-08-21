import AlarmKit
import AVFoundation
import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Query private var reminders: [Reminder]
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(AppStorageKeys.userName) private var storedUserName: String = ""
    @AppStorage(AppStorageKeys.voiceIdentifier) private var voiceIdentifier: String = ""
    @AppStorage(AppStorageKeys.speechRate) private var speechRate: Double = Double(AVSpeechUtteranceDefaultSpeechRate)
    @AppStorage(AppStorageKeys.speechPitch) private var speechPitch: Double = 1.0

    @State private var draftName: String = ""
    @State private var isShowingNameChangeConfirmation = false
    @State private var isRegeneratingAudio = false
    @State private var personalVoiceStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus = .notDetermined
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var alarmStatus: AlarmManager.AuthorizationState = .notDetermined

    private let audioService = AudioGenerationService()
    private let notificationService = NotificationService()
    private let alarmService = AlarmKitService()
    private let regenerator = ReminderAudioRegenerator()

    private static let minimumRate = Double(AVSpeechUtteranceMinimumSpeechRate)
    private static let maximumRate = Double(AVSpeechUtteranceMaximumSpeechRate)
    private static let minimumPitch = 0.5
    private static let maximumPitch = 2.0

    private var availableVoices: [AVSpeechSynthesisVoice] {
        AudioGenerationService.availableVoices()
    }

    var body: some View {
        Form {
            nameSection
            voiceSection
            permissionsSection
            aboutSection
        }
        .navigationTitle("Settings")
        .onAppear {
            draftName = storedUserName
            personalVoiceStatus = AVSpeechSynthesizer.personalVoiceAuthorizationStatus
            refreshPermissionStatuses()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { refreshPermissionStatuses() }
        }
        .alert("Regenerate All Reminder Audio?", isPresented: $isShowingNameChangeConfirmation) {
            Button("Cancel", role: .cancel) { draftName = storedUserName }
            Button("Save", action: applyNameChange)
        } message: {
            Text(
                "Since your name is spoken in your reminders, changing it will regenerate the audio for every reminder."
            )
        }
    }

    private var nameSection: some View {
        Section("Name") {
            TextField("Your name", text: $draftName)
            if draftName.trimmingCharacters(in: .whitespacesAndNewlines) != storedUserName {
                if isRegeneratingAudio {
                    ProgressView()
                } else {
                    Button("Save Name") { isShowingNameChangeConfirmation = true }
                        .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var voiceSection: some View {
        Section("Voice") {
            Picker("Voice", selection: $voiceIdentifier) {
                Text("System Default").tag("")
                ForEach(availableVoices, id: \.identifier) { voice in
                    Text(VoiceDisplay.label(for: voice)).tag(voice.identifier)
                }
            }
            .onChange(of: voiceIdentifier) { _, _ in regenerateAudioForVoiceSettingsChange() }

            Button("Preview Voice", action: previewVoice)

            if personalVoiceStatus != .authorized {
                Button("Set Up Personal Voice", action: requestPersonalVoiceAuthorization)
            }

            VStack(alignment: .leading) {
                Text("Rate: \(speechRate, format: .number.precision(.fractionLength(2)))")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Color.appTextSecondary)
                Slider(
                    value: $speechRate,
                    in: Self.minimumRate...Self.maximumRate,
                    onEditingChanged: { isEditing in if !isEditing { regenerateAudioForVoiceSettingsChange() } }
                )
            }

            VStack(alignment: .leading) {
                Text("Pitch: \(speechPitch, format: .number.precision(.fractionLength(2)))")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Color.appTextSecondary)
                Slider(
                    value: $speechPitch,
                    in: Self.minimumPitch...Self.maximumPitch,
                    onEditingChanged: { isEditing in if !isEditing { regenerateAudioForVoiceSettingsChange() } }
                )
            }

            Button("Reset to Defaults", action: resetVoiceDefaults)
        }
    }

    private var permissionsSection: some View {
        Section("Permissions") {
            LabeledContent("Notifications", value: notificationStatus.displayName)
            LabeledContent("Alarms", value: alarmStatus.displayName)
            Button("Open Settings", action: openSystemSettings)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersionString)
            if let supportURL = URL(string: "mailto:support@ajwadtahmid.com") {
                Link("Contact Support", destination: supportURL)
            }
            if let privacyURL = URL(string: "https://ajwadtahmid.github.io/privacy-policies/Crier-Plus.html") {
                Link("Privacy Policy", destination: privacyURL)
            }
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    private func applyNameChange() {
        storedUserName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            isRegeneratingAudio = true
            await regenerator.regenerateAll(reminders)
            isRegeneratingAudio = false
        }
    }

    private func regenerateAudioForVoiceSettingsChange() {
        Task {
            isRegeneratingAudio = true
            await regenerator.regenerateAll(reminders)
            isRegeneratingAudio = false
        }
    }

    private func resetVoiceDefaults() {
        voiceIdentifier = ""
        speechRate = Double(AVSpeechUtteranceDefaultSpeechRate)
        speechPitch = 1.0
        regenerateAudioForVoiceSettingsChange()
    }

    private func previewVoice() {
        Task {
            try? await audioService.speakPreview("Hi, this is a preview of your reminder voice.")
        }
    }

    private func requestPersonalVoiceAuthorization() {
        Task {
            personalVoiceStatus = await AudioGenerationService.requestPersonalVoiceAuthorization()
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func refreshPermissionStatuses() {
        Task {
            notificationStatus = await notificationService.authorizationStatus()
            alarmStatus = await alarmService.authorizationState
        }
    }
}

extension UNAuthorizationStatus {
    var displayName: String {
        switch self {
        case .authorized, .provisional, .ephemeral: return "Allowed"
        case .denied: return "Denied"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }
}

extension AlarmManager.AuthorizationState {
    var displayName: String {
        switch self {
        case .authorized: return "Allowed"
        case .denied: return "Denied"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: Reminder.self, inMemory: true)
}
