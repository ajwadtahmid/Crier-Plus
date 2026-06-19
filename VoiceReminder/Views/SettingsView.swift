import SwiftUI

struct SettingsView: View {
    @AppStorage(AppStorageKey.username) private var username = ""
    @AppStorage(AppStorageKey.speechRate) private var speechRate = 0.5
    @AppStorage(AppStorageKey.speechPitch) private var speechPitch = 1.0

    @State private var editedUsername = ""
    @State private var showUsernameAlert = false
    @State private var isUpdatingAudio = false
    @State private var updateProgress = ""

    private let audioService = AudioGenerationService()

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    HStack {
                        TextField("Your name", text: $editedUsername)
                            .frame(height: 44)
                        Button("Change") {
                            guard !editedUsername.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            showUsernameAlert = true
                        }
                        .disabled(editedUsername == username || editedUsername.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("Voice Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speech Rate")
                                .font(.system(size: 16))
                            Spacer()
                            Button {
                                audioService.speakPreview("The quick brown fox")
                            } label: {
                                Image(systemName: "speaker.wave.2")
                            }
                        }
                        HStack {
                            Text("Slow").font(.system(size: 12)).foregroundStyle(Color("TextSecondary"))
                            Slider(value: $speechRate, in: 0.3...1.5)
                            Text("Fast").font(.system(size: 12)).foregroundStyle(Color("TextSecondary"))
                        }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speech Pitch")
                                .font(.system(size: 16))
                            Spacer()
                            Button {
                                audioService.speakPreview("The quick brown fox")
                            } label: {
                                Image(systemName: "speaker.wave.2")
                            }
                        }
                        HStack {
                            Text("Low").font(.system(size: 12)).foregroundStyle(Color("TextSecondary"))
                            Slider(value: $speechPitch, in: 0.5...2.0)
                            Text("High").font(.system(size: 12)).foregroundStyle(Color("TextSecondary"))
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("AI") {
                    let status = checkAIAvailability()
                    HStack {
                        Text("Apple Intelligence")
                        Spacer()
                        switch status {
                        case .ready:
                            Text("Ready").foregroundStyle(Color("Accent"))
                        case .downloading:
                            Text("Downloading...").foregroundStyle(.orange)
                        default:
                            Text("Not available").foregroundStyle(Color("TextSecondary"))
                        }
                    }

                    if status != .ready {
                        Text(statusDescription(status))
                            .font(.system(size: 14))
                            .foregroundStyle(Color("TextSecondary"))
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { editedUsername = username }
            .alert("Update reminders?", isPresented: $showUsernameAlert) {
                Button("Cancel", role: .cancel) { editedUsername = username }
                Button("Update") {
                    username = editedUsername
                }
            } message: {
                Text("Update audio for all existing reminders with new name?")
            }
        }
    }

    private func statusDescription(_ status: AIAvailabilityStatus) -> String {
        switch status {
        case .unsupportedDevice: return "Requires Apple Intelligence-capable device"
        case .needsToEnableInSettings: return "Enable Apple Intelligence in Settings"
        case .downloading: return "Apple Intelligence model is downloading"
        default: return "Apple Intelligence unavailable"
        }
    }
}
