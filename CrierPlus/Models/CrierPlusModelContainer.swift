import SwiftData

/// Shared factory for the app's persistent `ModelContainer`, so anything that needs to touch
/// SwiftData outside the normal view hierarchy — an `AppIntent` responding to a Live Activity
/// button while the app isn't running, for instance — opens the same on-disk store rather than
/// duplicating this setup.
enum CrierPlusModelContainer {
    /// A process-wide singleton. `AlarmActionHandler`'s call sites (`AlarmRingView`,
    /// `NotificationDelegate`, `DismissAlarmIntent`) all default to this rather than calling
    /// `make()` fresh each time — two independent `ModelContainer` instances open on the same
    /// on-disk store don't observe each other's writes (no persistent-history merging is
    /// configured), so a fresh container per call left `ReminderListView`'s `@Query` unaware of a
    /// dismiss/snooze write until the app relaunched. A single shared instance per process means
    /// in-process callers (the common case: the app is already running) share the exact same
    /// container `ReminderListView` reads from; a fully-detached intent invocation still gets a
    /// working container lazily on first access, with no other instance in that process to race.
    static let shared: ModelContainer = try! make()

    static func make() throws -> ModelContainer {
        let schema = Schema(versionedSchema: CrierPlusSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema)
        return try ModelContainer(
            for: schema,
            migrationPlan: CrierPlusMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
