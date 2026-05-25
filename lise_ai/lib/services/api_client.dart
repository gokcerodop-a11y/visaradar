// api_client.dart — re-export shim (Phase 3 of the OmniCore migration).
// Canonical source moved to `package:omnicore_foundation/omnicore_foundation.dart`.

export 'package:omnicore_foundation/omnicore_foundation.dart'
    show
        ApiClient,
        ApiException,
        ApiRequest,
        ApiResponse,
        NetworkStateGuard,
        RateLimitHandler,
        RetryPolicy,
        TimeoutPolicy;
