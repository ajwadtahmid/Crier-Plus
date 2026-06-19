import SwiftUI
import SwiftData
import UserNotifications

@main
struct VoiceReminderApp: App {
    @AppStorage(AppStorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false

    let container: ModelContainer
    @StateObject private var notificationDelegate = AppNotificationDelegate()

    init() {
        do {
            container = try ModelContainer(for: Reminder.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ReminderListView()
                    .modelContainer(container)
            } else {
                OnboardingView()
                    .modelContainer(container)
            }
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @AppStorage(AppStorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(AppStorageKey.username) private var username = ""

    @State private var enteredName = ""
    @State private var showToast = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color("Primary"))

                VStack(spacing: 8) {
                    Text("Welcome to Crier Plus")
                        .font(.system(size: 28, weight: .semibold))
                        .multilineTextAlignment(.center)

                    Text("Voice reminders that speak your name")
                        .font(.system(size: 16))
                        .foregroundStyle(Color("TextSecondary"))
                        .multilineTextAlignment(.center)
                }

                TextField("Your name", text: $enteredName)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .frame(width: 200, height: 44)
                    .background(Color("SecondaryBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("Border"), lineWidth: 1))

                Spacer()

                Button {
                    guard !enteredName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    username = enteredName.trimmingCharacters(in: .whitespaces)
                    withAnimation { showToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        hasCompletedOnboarding = true
                    }
                    requestNotificationPermission()
                } label: {
                    Text("Continue")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(enteredName.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color("Primary").opacity(0.5) : Color("Primary"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(enteredName.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .overlay(alignment: .top) {
                if showToast {
                    Text("All set, \(enteredName)!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color("Accent"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 60)
                        .transition(.opacity)
                }
            }
        }
    }

    private func requestNotificationPermission() {
        Task {
            try? await NotificationService.shared.requestPermission()
        }
    }
}

// MARK: - Notification Delegate

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
