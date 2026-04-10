import 'dart:convert';

/// User preferences for which notification categories and thresholds are active.
class NotificationPreferences {
  const NotificationPreferences({
    this.schengenAlert30 = true,
    this.schengenAlert15 = true,
    this.schengenAlert7  = true,
    this.schengenAlert3  = true,
    this.schengenAlert1  = true,
    this.ongoingStayReminder        = true,
    this.dismissedCrossingReminder  = true,
    this.locationInactiveReminder   = false,
  });

  /// Warn when 30 days of Schengen allowance remain.
  final bool schengenAlert30;

  /// Warn when 15 days of Schengen allowance remain.
  final bool schengenAlert15;

  /// Warn when 7 days of Schengen allowance remain.
  final bool schengenAlert7;

  /// Warn when 3 days of Schengen allowance remain.
  final bool schengenAlert3;

  /// Warn when 1 day of Schengen allowance remains.
  final bool schengenAlert1;

  /// Reminder that the user still has an open trip that needs an exit date.
  final bool ongoingStayReminder;

  /// Reminder to review trips manually after a crossing suggestion was dismissed.
  final bool dismissedCrossingReminder;

  /// Reminder when location access is off, limiting automatic border detection.
  final bool locationInactiveReminder;

  NotificationPreferences copyWith({
    bool? schengenAlert30,
    bool? schengenAlert15,
    bool? schengenAlert7,
    bool? schengenAlert3,
    bool? schengenAlert1,
    bool? ongoingStayReminder,
    bool? dismissedCrossingReminder,
    bool? locationInactiveReminder,
  }) {
    return NotificationPreferences(
      schengenAlert30:           schengenAlert30           ?? this.schengenAlert30,
      schengenAlert15:           schengenAlert15           ?? this.schengenAlert15,
      schengenAlert7:            schengenAlert7            ?? this.schengenAlert7,
      schengenAlert3:            schengenAlert3            ?? this.schengenAlert3,
      schengenAlert1:            schengenAlert1            ?? this.schengenAlert1,
      ongoingStayReminder:       ongoingStayReminder       ?? this.ongoingStayReminder,
      dismissedCrossingReminder: dismissedCrossingReminder ?? this.dismissedCrossingReminder,
      locationInactiveReminder:  locationInactiveReminder  ?? this.locationInactiveReminder,
    );
  }

  Map<String, dynamic> toJson() => {
        'schengenAlert30':           schengenAlert30,
        'schengenAlert15':           schengenAlert15,
        'schengenAlert7':            schengenAlert7,
        'schengenAlert3':            schengenAlert3,
        'schengenAlert1':            schengenAlert1,
        'ongoingStayReminder':       ongoingStayReminder,
        'dismissedCrossingReminder': dismissedCrossingReminder,
        'locationInactiveReminder':  locationInactiveReminder,
      };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      schengenAlert30:           json['schengenAlert30']           as bool? ?? true,
      schengenAlert15:           json['schengenAlert15']           as bool? ?? true,
      schengenAlert7:            json['schengenAlert7']            as bool? ?? true,
      schengenAlert3:            json['schengenAlert3']            as bool? ?? true,
      schengenAlert1:            json['schengenAlert1']            as bool? ?? true,
      ongoingStayReminder:       json['ongoingStayReminder']       as bool? ?? true,
      dismissedCrossingReminder: json['dismissedCrossingReminder'] as bool? ?? true,
      locationInactiveReminder:  json['locationInactiveReminder']  as bool? ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory NotificationPreferences.fromJsonString(String s) =>
      NotificationPreferences.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
