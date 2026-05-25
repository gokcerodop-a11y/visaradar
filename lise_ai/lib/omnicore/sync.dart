// sync.dart
// Barrel for the future `omnicore_sync` package.
//
// Offline-first sync queue + backend adapters (Supabase + Firebase).
// Phase 6 moves these; adapters move as a unit under
// `packages/omnicore_sync/lib/src/adapters/`.

export '../services/adapters/backend_adapters.dart';
export '../services/auth_service.dart';
export '../services/backend_provider_service.dart';
export '../services/supabase_sync_service.dart';
export '../services/sync_queue.dart';
export '../services/sync_repository.dart';
