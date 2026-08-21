import AlarmKit

/// Placeholder Live Activity metadata for AlarmKit's generic `Metadata` parameter. Shared verbatim
/// between the app target (which schedules `AlarmAttributes<EmptyAlarmMetadata>`) and the widget
/// extension target (which renders the matching Live Activity) — both must compile the identical
/// type for `AlarmAttributes<EmptyAlarmMetadata>` to line up across the two targets.
struct EmptyAlarmMetadata: AlarmMetadata {}
