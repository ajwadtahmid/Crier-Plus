import Foundation
import UserNotifications

@testable import CrierPlus

/// Deterministic in-memory stand-in for `UNUserNotificationCenter`, since the real center's
/// pending-request round trip isn't reliably observable from within an `.xctest` test host.
///
/// A plain class rather than an actor: `UNNotificationRequest` isn't `Sendable`, and tests only
/// ever call this sequentially via `await`, so there's no real concurrent access to guard against.
final class FakeNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    private(set) var requestsByIdentifier: [String: UNNotificationRequest] = [:]
    var authorizationGranted = true

    func add(_ request: UNNotificationRequest) async throws {
        requestsByIdentifier[request.identifier] = request
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        Array(requestsByIdentifier.values)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        for identifier in identifiers {
            requestsByIdentifier.removeValue(forKey: identifier)
        }
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationGranted
    }
}
