# omnicore_foundation

Foundation utilities for the **OmniCore AI Engine**.

## Status — Phase 1

This package is a **skeleton**. Real code lands in Phase 3 of the OmniCore
migration. The package exists today so that:

- the monorepo `packages/` layout is in place
- dependent apps (LiseAI, VisaRadar, future verticals) can wire up imports
- `melos bootstrap` and `flutter pub get` flows are validated against an
  empty-but-real package

## Planned contents (Phase 3)

Extracted from `lise_ai/lib/services/` after light decoupling:

- `app_logger` — debug printer
- `connectivity_service` — DNS-lookup-based online/offline detection
- `crash_reporter` — pluggable crash backend interface (Crashlytics, Sentry, no-op)
- `error_handler` — generic `AppErrorType` enum + classification
- `api_client` — HTTP retry / backoff / timeout policies
- `haptics_service` — platform haptics wrapper
- `storage_service` — Hive key-value box (box name passed in by app)
- `runtime_stability_monitor` — passive runtime health observer
- `runtime_validation_service` — active validation suite

## Usage

Not yet — see Phase 3 of `docs/architecture/omnicore_migration_plan.md`.
