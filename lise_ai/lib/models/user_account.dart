import 'dart:convert';

// ── AuthProvider ──────────────────────────────────────────────────────────────

enum AuthProvider {
  apple,
  google,
  anonymous,  // ephemeral — no persistence across installs
  guest,      // local account — persists on device
}

extension AuthProviderExt on AuthProvider {
  String get label => switch (this) {
        AuthProvider.apple     => 'Apple',
        AuthProvider.google    => 'Google',
        AuthProvider.anonymous => 'Anonim',
        AuthProvider.guest     => 'Misafir',
      };

  bool get isLocal => this == AuthProvider.guest || this == AuthProvider.anonymous;
  bool get isSocial => this == AuthProvider.apple || this == AuthProvider.google;
}

// ── UserAccount ───────────────────────────────────────────────────────────────

class UserAccount {
  final String id;              // stable local UUID or server-assigned ID
  final AuthProvider provider;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final bool isVerified;        // email verified (social providers = true)

  const UserAccount({
    required this.id,
    required this.provider,
    this.email,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
    this.isVerified = false,
  });

  bool get isAnonymous  => provider == AuthProvider.anonymous;
  bool get isGuest      => provider == AuthProvider.guest;
  bool get isSocial     => provider.isSocial;
  String get safeDisplayName =>
      displayName ?? email?.split('@').first ?? 'Öğrenci';

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider.name,
        'email': email,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'createdAt': createdAt.toIso8601String(),
        'isVerified': isVerified,
      };

  factory UserAccount.fromJson(Map<String, dynamic> j) => UserAccount(
        id: j['id'] as String,
        provider: AuthProvider.values.firstWhere(
          (p) => p.name == j['provider'],
          orElse: () => AuthProvider.guest,
        ),
        email: j['email'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        isVerified: j['isVerified'] as bool? ?? false,
      );

  UserAccount copyWith({
    String? displayName,
    String? email,
    String? avatarUrl,
    bool? isVerified,
  }) => UserAccount(
        id: id,
        provider: provider,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt,
        isVerified: isVerified ?? this.isVerified,
      );
}

// ── CloudSession ──────────────────────────────────────────────────────────────

class CloudSession {
  final String sessionId;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String deviceId;
  final String appVersion;
  final bool isSynced;

  const CloudSession({
    required this.sessionId,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    required this.deviceId,
    required this.appVersion,
    this.isSynced = false,
  });

  Duration get duration =>
      (endedAt ?? DateTime.now()).difference(startedAt);

  bool get isActive => endedAt == null;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'userId': userId,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'deviceId': deviceId,
        'appVersion': appVersion,
        'isSynced': isSynced,
      };

  factory CloudSession.fromJson(Map<String, dynamic> j) => CloudSession(
        sessionId: j['sessionId'] as String,
        userId: j['userId'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: j['endedAt'] != null
            ? DateTime.tryParse(j['endedAt'] as String)
            : null,
        deviceId: j['deviceId'] as String,
        appVersion: j['appVersion'] as String,
        isSynced: j['isSynced'] as bool? ?? false,
      );
}

// ── SyncedLesson ──────────────────────────────────────────────────────────────

class SyncedLesson {
  final String lessonId;
  final String userId;
  final String topic;
  final List<Map<String, dynamic>> messages; // [{role, content}]
  final DateTime startedAt;
  final DateTime lastUpdatedAt;
  final bool isComplete;
  final double avgSuccessEstimate;
  final String? lessonMode;

  const SyncedLesson({
    required this.lessonId,
    required this.userId,
    required this.topic,
    required this.messages,
    required this.startedAt,
    required this.lastUpdatedAt,
    this.isComplete = false,
    this.avgSuccessEstimate = 0.5,
    this.lessonMode,
  });

  Map<String, dynamic> toJson() => {
        'lessonId': lessonId,
        'userId': userId,
        'topic': topic,
        'messages': messages,
        'startedAt': startedAt.toIso8601String(),
        'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
        'isComplete': isComplete,
        'avgSuccessEstimate': avgSuccessEstimate,
        'lessonMode': lessonMode,
      };

  factory SyncedLesson.fromJson(Map<String, dynamic> j) => SyncedLesson(
        lessonId: j['lessonId'] as String,
        userId: j['userId'] as String,
        topic: j['topic'] as String,
        messages: (j['messages'] as List<dynamic>)
            .cast<Map<String, dynamic>>(),
        startedAt: DateTime.parse(j['startedAt'] as String),
        lastUpdatedAt: DateTime.parse(j['lastUpdatedAt'] as String),
        isComplete: j['isComplete'] as bool? ?? false,
        avgSuccessEstimate:
            (j['avgSuccessEstimate'] as num?)?.toDouble() ?? 0.5,
        lessonMode: j['lessonMode'] as String?,
      );
}

// ── RemoteAnalyticsEvent ──────────────────────────────────────────────────────

class RemoteAnalyticsEvent {
  final String eventType;
  final DateTime timestamp;
  final Map<String, dynamic> properties;

  const RemoteAnalyticsEvent({
    required this.eventType,
    required this.timestamp,
    this.properties = const {},
  });

  Map<String, dynamic> toJson() => {
        'eventType': eventType,
        'timestamp': timestamp.toIso8601String(),
        'properties': properties,
      };
}

// ── RemoteAnalytics ───────────────────────────────────────────────────────────

class RemoteAnalytics {
  final String userId;
  final List<RemoteAnalyticsEvent> events;
  final DateTime collectedAt;

  const RemoteAnalytics({
    required this.userId,
    required this.events,
    required this.collectedAt,
  });

  /// Convert to JSON payload ready for a future analytics endpoint.
  String toPayload() => jsonEncode({
        'userId': userId,
        'collectedAt': collectedAt.toIso8601String(),
        'events': events.map((e) => e.toJson()).toList(),
      });
}
