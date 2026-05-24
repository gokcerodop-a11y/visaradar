import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ── Policies ──────────────────────────────────────────────────────────────────

class RetryPolicy {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffFactor;  // delay multiplier per retry

  const RetryPolicy({
    this.maxAttempts  = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffFactor = 2.0,
  });

  static const none    = RetryPolicy(maxAttempts: 1);
  static const default_ = RetryPolicy();
  static const aggressive = RetryPolicy(maxAttempts: 5, initialDelay: Duration(milliseconds: 500));

  Duration delayForAttempt(int attempt) {
    final ms = initialDelay.inMilliseconds *
        (backoffFactor * (attempt - 1)).clamp(0.0, 60000.0);
    return Duration(milliseconds: ms.toInt());
  }
}

class TimeoutPolicy {
  final Duration connect;
  final Duration receive;

  const TimeoutPolicy({
    this.connect = const Duration(seconds: 10),
    this.receive = const Duration(seconds: 30),
  });

  static const fast    = TimeoutPolicy(connect: Duration(seconds: 5),  receive: Duration(seconds: 10));
  static const default_ = TimeoutPolicy();
  static const long    = TimeoutPolicy(connect: Duration(seconds: 15), receive: Duration(seconds: 90));
}

// ── ApiRequest / ApiResponse ──────────────────────────────────────────────────

class ApiRequest {
  final String path;
  final String method;
  final Map<String, String> headers;
  final Object? body;
  final RetryPolicy retryPolicy;
  final TimeoutPolicy timeoutPolicy;

  const ApiRequest({
    required this.path,
    this.method = 'GET',
    this.headers = const {},
    this.body,
    this.retryPolicy = RetryPolicy.default_,
    this.timeoutPolicy = TimeoutPolicy.default_,
  });

  ApiRequest withAuth(String token) => ApiRequest(
        path: path,
        method: method,
        headers: {...headers, 'Authorization': 'Bearer $token'},
        body: body,
        retryPolicy: retryPolicy,
        timeoutPolicy: timeoutPolicy,
      );
}

class ApiResponse {
  final int statusCode;
  final Map<String, dynamic>? body;
  final String? rawBody;
  final bool fromCache;

  const ApiResponse({
    required this.statusCode,
    this.body,
    this.rawBody,
    this.fromCache = false,
  });

  bool get isSuccess  => statusCode >= 200 && statusCode < 300;
  bool get isNotFound => statusCode == 404;
  bool get isUnauth   => statusCode == 401;
  bool get isRateLimited => statusCode == 429;
}

// ── ApiException ──────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final bool isRetryable;

  const ApiException({
    this.statusCode,
    required this.message,
    this.isRetryable = false,
  });

  @override
  String toString() => 'ApiException[$statusCode]: $message';
}

// ── RateLimitHandler ──────────────────────────────────────────────────────────

class RateLimitHandler {
  final int maxRequestsPerMinute;
  final List<DateTime> _requestTimestamps = [];

  RateLimitHandler({this.maxRequestsPerMinute = 60});

  bool get isThrottled {
    _prune();
    return _requestTimestamps.length >= maxRequestsPerMinute;
  }

  void recordRequest() {
    _requestTimestamps.add(DateTime.now());
  }

  Duration get retryAfter {
    _prune();
    if (_requestTimestamps.isEmpty) return Duration.zero;
    final oldest = _requestTimestamps.first;
    final windowEnd = oldest.add(const Duration(minutes: 1));
    final diff = windowEnd.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    _requestTimestamps.removeWhere((t) => t.isBefore(cutoff));
  }
}

// ── NetworkStateGuard ─────────────────────────────────────────────────────────

class NetworkStateGuard {
  NetworkStateGuard._();

  /// Returns true if the device appears to have internet connectivity.
  /// Uses a lightweight DNS lookup — does not guarantee full connectivity.
  static Future<bool> hasConnectivity() async {
    try {
      final result = await InternetAddress.lookup('api.anthropic.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

// ── ApiClient ─────────────────────────────────────────────────────────────────

/// HTTP client abstraction with retry, timeout, and rate-limit support.
///
/// Wire a [baseUrl] and optional [defaultHeaders] at construction.
/// Use [execute] for all requests — it handles retry loops and error
/// classification automatically.
///
/// To add a real backend: inject the base URL from [EnvironmentConfig].
class ApiClient {
  final String baseUrl;
  final Map<String, String> defaultHeaders;
  final RateLimitHandler _rateLimiter;

  ApiClient({
    required this.baseUrl,
    this.defaultHeaders = const {
      'Content-Type': 'application/json',
      'Accept':       'application/json',
    },
    int maxRpm = 60,
  }) : _rateLimiter = RateLimitHandler(maxRequestsPerMinute: maxRpm);

  // ── Execute ───────────────────────────────────────────────────────────────

  Future<ApiResponse> execute(ApiRequest request) async {
    // Rate-limit guard.
    if (_rateLimiter.isThrottled) {
      throw ApiException(
        statusCode: 429,
        message: 'Rate limit exceeded locally. Retry after ${_rateLimiter.retryAfter.inSeconds}s.',
        isRetryable: true,
      );
    }

    int attempt = 0;
    ApiException? lastError;

    while (attempt < request.retryPolicy.maxAttempts) {
      attempt++;
      try {
        _rateLimiter.recordRequest();
        final response = await _doRequest(request);

        if (response.isRateLimited) {
          // Wait and retry on 429.
          await Future<void>.delayed(const Duration(seconds: 5));
          continue;
        }

        return response;
      } on ApiException catch (e) {
        lastError = e;
        if (!e.isRetryable || attempt >= request.retryPolicy.maxAttempts) {
          rethrow;
        }
        await Future<void>.delayed(request.retryPolicy.delayForAttempt(attempt));
      } on TimeoutException {
        lastError = const ApiException(
          message: 'Request timed out',
          isRetryable: true,
        );
        if (attempt >= request.retryPolicy.maxAttempts) throw lastError;
        await Future<void>.delayed(request.retryPolicy.delayForAttempt(attempt));
      } on SocketException catch (e) {
        throw ApiException(
          message: 'Network error: ${e.message}',
          isRetryable: false,
        );
      }
    }

    throw lastError ?? const ApiException(message: 'Unknown error after retries');
  }

  // ── Internal HTTP ──────────────────────────────────────────────────────────

  Future<ApiResponse> _doRequest(ApiRequest req) async {
    final uri = Uri.parse('$baseUrl${req.path}');
    final merged = {...defaultHeaders, ...req.headers};

    final client = HttpClient()
      ..connectionTimeout = req.timeoutPolicy.connect;

    try {
      final httpReq = await client.openUrl(req.method, uri)
          .timeout(req.timeoutPolicy.connect);

      for (final h in merged.entries) {
        httpReq.headers.set(h.key, h.value);
      }

      if (req.body != null) {
        final bodyBytes = utf8.encode(jsonEncode(req.body));
        httpReq.headers.contentLength = bodyBytes.length;
        httpReq.add(bodyBytes);
      }

      final httpRes = await httpReq.close()
          .timeout(req.timeoutPolicy.receive);

      final raw = await httpRes.transform(utf8.decoder).join()
          .timeout(req.timeoutPolicy.receive);

      Map<String, dynamic>? parsed;
      try { parsed = jsonDecode(raw) as Map<String, dynamic>?; } catch (_) {}

      final status = httpRes.statusCode;
      if (status >= 500) {
        throw ApiException(
          statusCode: status,
          message: 'Server error $status',
          isRetryable: true,
        );
      }

      return ApiResponse(statusCode: status, body: parsed, rawBody: raw);
    } finally {
      client.close(force: false);
    }
  }
}
