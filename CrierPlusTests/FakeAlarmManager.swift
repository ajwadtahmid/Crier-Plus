import AlarmKit
import Foundation

@testable import CrierPlus

/// Deterministic in-memory stand-in for `AlarmManager`, since the real singleton talks to a
/// system XPC daemon that isn't reliably observable — or authorizable — from an `.xctest` host.
final class FakeAlarmManager: AlarmManagerProtocol, @unchecked Sendable {
    var authorizationState: AlarmManager.AuthorizationState
    private(set) var scheduledAlarmIDs: Set<UUID> = []
    private(set) var cancelledAlarmIDs: [UUID] = []

    init(authorizationState: AlarmManager.AuthorizationState = .authorized) {
        self.authorizationState = authorizationState
    }

    func requestAuthorization() async throws -> AlarmManager.AuthorizationState {
        authorizationState
    }

    func scheduleAlarm<Metadata: AlarmMetadata>(
        id: Alarm.ID,
        configuration: AlarmManager.AlarmConfiguration<Metadata>
    ) async throws {
        scheduledAlarmIDs.insert(id)
    }

    func cancel(id: Alarm.ID) throws {
        scheduledAlarmIDs.remove(id)
        cancelledAlarmIDs.append(id)
    }

    private(set) var stoppedAlarmIDs: [UUID] = []
    private(set) var countdownAlarmIDs: [UUID] = []

    func stop(id: Alarm.ID) throws {
        stoppedAlarmIDs.append(id)
    }

    func countdown(id: Alarm.ID) throws {
        countdownAlarmIDs.append(id)
    }
}
