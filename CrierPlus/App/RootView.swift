import SwiftUI

enum RootDestination: Equatable {
    case onboarding
    case main

    init(hasCompletedOnboarding: Bool) {
        self = hasCompletedOnboarding ? .main : .onboarding
    }
}

struct RootView: View {
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding: Bool = false
    private let coordinator = RingPresentationCoordinator.shared

    var body: some View {
        Group {
            switch RootDestination(hasCompletedOnboarding: hasCompletedOnboarding) {
            case .onboarding:
                OnboardingView()
            case .main:
                ReminderListView()
            }
        }
        .task { await coordinator.observeAlarmAlerts() }
        .fullScreenCover(
            item: Binding(
                get: { coordinator.presentation },
                set: { newValue in
                    if newValue == nil { coordinator.dismissPresentation() }
                }
            )
        ) { presentation in
            AlarmRingView(reminderID: presentation.reminderID, path: presentation.path) {
                coordinator.dismissPresentation()
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
