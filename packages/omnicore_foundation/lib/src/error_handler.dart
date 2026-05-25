import 'package:flutter/material.dart';

// ── AppErrorType ──────────────────────────────────────────────────────────────

enum AppErrorType {
  api,          // Claude API failure
  stt,          // Speech-to-text failure
  tts,          // Text-to-speech failure
  pdf,          // PDF parsing failure
  image,        // Image upload/decode failure
  storage,      // Hive/local storage failure
  network,      // No internet / timeout
  permission,   // Mic/camera permission denied
  unknown,      // Catch-all
}

// ── AppError ──────────────────────────────────────────────────────────────────

class AppError {
  final AppErrorType type;
  final String technicalMessage;  // for logs only
  final Object? originalError;

  const AppError({
    required this.type,
    required this.technicalMessage,
    this.originalError,
  });

  /// User-facing Turkish message — safe for display.
  String get userMessage => switch (type) {
        AppErrorType.api =>
          'AI hizmetine bağlanılamadı. İnternet bağlantınızı kontrol edin.',
        AppErrorType.stt =>
          'Ses tanıma başlatılamadı. Mikrofon izninizi kontrol edin.',
        AppErrorType.tts =>
          'Sesli yanıt çalınamadı. Lütfen tekrar deneyin.',
        AppErrorType.pdf =>
          'PDF dosyası açılamadı. Dosyanın bozuk olmadığından emin olun.',
        AppErrorType.image =>
          'Görsel yüklenemedi. Desteklenen formatlar: JPG, PNG.',
        AppErrorType.storage =>
          'Veriler kaydedilemedi. Cihaz depolama alanını kontrol edin.',
        AppErrorType.network =>
          'İnternet bağlantısı bulunamadı. AI özellikler için bağlantı gereklidir.',
        AppErrorType.permission =>
          'İzin verilmedi. Ayarlar\'dan izin vermeyi unutmayın.',
        AppErrorType.unknown =>
          'Beklenmeyen bir hata oluştu. Lütfen uygulamayı yeniden başlatın.',
      };

  /// Short label for snackbar action area.
  String get shortLabel => switch (type) {
        AppErrorType.api       => 'API Hatası',
        AppErrorType.stt       => 'Ses Hatası',
        AppErrorType.tts       => 'TTS Hatası',
        AppErrorType.pdf       => 'PDF Hatası',
        AppErrorType.image     => 'Görsel Hatası',
        AppErrorType.storage   => 'Depolama Hatası',
        AppErrorType.network   => 'Bağlantı Yok',
        AppErrorType.permission => 'İzin Hatası',
        AppErrorType.unknown   => 'Hata',
      };
}

// ── ErrorHandler ──────────────────────────────────────────────────────────────
//
// Crash-safe wrapper utilities. All operations return null/fallback on failure
// instead of throwing. Errors are logged (debugPrint) and optionally shown via
// the context-based display method.

class ErrorHandler {
  ErrorHandler._();

  /// Classify a raw exception into an AppError.
  static AppError classify(Object error, {String? context}) {
    final msg = error.toString().toLowerCase();

    AppErrorType type;
    if (msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('host lookup')) {
      type = AppErrorType.network;
    } else if (msg.contains('api') ||
        msg.contains('anthropic') ||
        msg.contains('401') ||
        msg.contains('403') ||
        msg.contains('rate limit') ||
        msg.contains('overloaded')) {
      type = AppErrorType.api;
    } else if (msg.contains('speech') ||
        msg.contains('stt') ||
        msg.contains('microphone') ||
        msg.contains('recognition')) {
      type = AppErrorType.stt;
    } else if (msg.contains('tts') || msg.contains('voice')) {
      type = AppErrorType.tts;
    } else if (msg.contains('pdf') || msg.contains('pdfium')) {
      type = AppErrorType.pdf;
    } else if (msg.contains('image') ||
        msg.contains('decode') ||
        msg.contains('codec')) {
      type = AppErrorType.image;
    } else if (msg.contains('hive') ||
        msg.contains('box') ||
        msg.contains('storage') ||
        msg.contains('permission denied')) {
      type = AppErrorType.storage;
    } else if (msg.contains('permission')) {
      type = AppErrorType.permission;
    } else {
      type = AppErrorType.unknown;
    }

    return AppError(
      type: type,
      technicalMessage: context != null ? '[$context] $error' : '$error',
      originalError: error,
    );
  }

  /// Run [fn] safely, returning null on any error.
  /// Logs error with [context] tag, optionally shows snackbar via [buildContext].
  static Future<T?> wrap<T>(
    Future<T> Function() fn, {
    String context = 'App',
    BuildContext? buildContext,
    bool showSnackbar = false,
  }) async {
    try {
      return await fn();
    } catch (e, st) {
      final err = classify(e, context: context);
      debugPrint('[ErrorHandler] ${err.technicalMessage}');
      debugPrintStack(stackTrace: st, maxFrames: 6);
      if (showSnackbar && buildContext != null && buildContext.mounted) {
        _showSnackbar(buildContext, err);
      }
      return null;
    }
  }

  /// Run [fn] safely, returning [fallback] on any error.
  static Future<T> wrapWithFallback<T>(
    Future<T> Function() fn,
    T fallback, {
    String context = 'App',
  }) async {
    try {
      return await fn();
    } catch (e) {
      final err = classify(e, context: context);
      debugPrint('[ErrorHandler] ${err.technicalMessage}');
      return fallback;
    }
  }

  /// Show a themed error snackbar in Turkish.
  static void show(BuildContext context, Object error, {String? tag}) {
    if (!context.mounted) return;
    final err = classify(error, context: tag);
    _showSnackbar(context, err);
  }

  /// Show a custom Turkish message snackbar.
  static void showMessage(BuildContext context, String message, {bool isError = true}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: isError
            ? const Color(0xFF991B1B)
            : const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void _showSnackbar(BuildContext context, AppError err) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              err.shortLabel,
              style: const TextStyle(
                color: Color(0xFFFCA5A5),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              err.userMessage,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1F1F2E),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF7C6BF8), width: 0.5),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
