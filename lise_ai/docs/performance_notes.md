# LiseAI — Performance & Stability Notes

**Version**: 1.0.0
**Last updated**: 2026-05-24
**Scope**: Bottlenecks, rebuild-heavy widgets, memory-heavy systems, and
candidate optimizations for a post-stability refactor.

This document is **observational**, not a refactor plan. The current build
is stable for TestFlight; everything below is queued for *after* release.

---

## 1. Probable bottlenecks

### 1.1 Streaming chat render path
- `ai_os_screen.dart` renders the active conversation list on every token
  arrival from `AnthropicService`. The whole list is rebuilt instead of just
  the streaming bubble.
- Mitigation candidate: split active-message into its own `StatefulWidget`
  with `ValueListenable<String>` for the streaming buffer.

### 1.2 Whiteboard repaint
- `lesson_board_page.dart` paints all strokes on every gesture frame via
  a single `CustomPainter`. With 200+ strokes, this becomes the dominant
  frame cost.
- Mitigation candidate: cache completed strokes to a `PictureLayer` /
  `RepaintBoundary` and only repaint the in-progress stroke.

### 1.3 Onboarding orb animation
- Multiple `AnimationController`s overlap during onboarding (orb, ambient
  layer, parallax). Total active controllers: ~5.
- Low risk; only fires for ~30 s during onboarding. Leave for now.

### 1.4 PDF page rendering
- `pdf_service.dart` renders each page synchronously via `pdfx`. Large PDFs
  (50+ pages) block the UI for ~200 ms per page on initial open.
- Mitigation candidate: lazily render only visible thumbnails.

---

## 2. Rebuild-heavy widgets

| Widget | Trigger | Rebuild scope | Recommended scope |
|---|---|---|---|
| `AIOperatingSystemScreen` | Token stream tick | Entire tree | Just message bubble |
| `LessonBoardPage` | Pen gesture frame | Entire `CustomPaint` | Active stroke layer only |
| `VoiceConversationPage` | Live subtitle tick | Subtitle + orb | Subtitle text only |
| `DiagnosticsScreen` | Sync status change | Whole sync card | `ListenableBuilder` already scoped |
| `OnboardingScreen` | Step change | Full page | Step transitions only |

---

## 3. Memory-heavy systems

### 3.1 Long-term memory
- `LongTermMemory` keeps `SubjectMastery` and `MistakePattern` records
  in-memory for the session. Growth is bounded by topic count (~50) so
  this is not currently a leak vector.

### 3.2 Conversation history
- `StorageService` reads full conversations into memory on load. A 200-turn
  conversation = ~200 KB. Fine for now; if conversations grow into thousands
  of messages, paginate from Hive.

### 3.3 PDF page images
- Each rendered PDF page is held as `Uint8List` (~500 KB-1.5 MB). Keep a
  weak cache, drop on page change. Currently held only during preview.

### 3.4 Whiteboard strokes
- Strokes are kept as `List<Offset>` in memory. 1 hour of intense use
  ≈ 50,000 points ≈ 800 KB. Acceptable; flush completed lessons to disk
  if we add multi-session board persistence.

### 3.5 Telemetry queue
- Capped at 500 events (`TelemetryService._maxQueueSize`) — bounded.

### 3.6 Streaming buffers
- `streaming_teacher_session.dart` accumulates tokens into a `StringBuffer`
  per stream. Released on stream completion. No leak observed.

---

## 4. Future optimization ideas

| Idea | Effort | Win | Priority |
|---|---|---|---|
| Repaint-boundary the whiteboard stroke layer | M | Smooth 60 fps at 500+ strokes | High |
| ValueListenable for the streaming message bubble | S | Halves frame cost during streams | High |
| Lazy PDF thumbnail rendering | M | Removes 100 ms+ stalls on large PDFs | Medium |
| Hive-backed message pagination | M | Bounds memory on huge conversations | Medium |
| Move heavy memory engines off the UI isolate | L | Frees main isolate during analysis | Low |
| Pre-compile WGSL/Metal shaders | S | Reduces first-paint stutter on iOS | Low |
| Use `const` for unchanged decorations | S | Trivial GC pressure reduction | Low |

S = <1 day, M = 1-3 days, L = 1 week+.

---

## 5. Future modularization candidates

Current `lib/services/` has ~60 files in one folder. After stability is
proven on TestFlight, consider extracting:

| Module candidate | Files | Reason |
|---|---|---|
| `core/ai/` | `anthropic_service`, `streaming_teacher_session`, `teacher_engine` | Tightly coupled |
| `core/memory/` | `*_memory.dart`, `memory_*`, `session_*` | Single concern |
| `core/voice/` | `speech_service`, `teacher_voice_service`, `realtime_voice_engine`, `voice_*` | Clear cluster |
| `core/board/` | `teacher_pen_engine`, `board_redraw_service`, `lesson_*` | UI + service boundary |
| `core/backend/` | `supabase_*`, `backend_provider_service`, `sync_*` | Hot-swappable |
| `core/observability/` | `crash_reporter`, `telemetry_service`, `release_validator`, `runtime_*` | Cross-cutting |

**Do not perform this refactor yet** — defer until after first 1 000 real
users, when actual coupling points are observed.

---

## 6. Stability invariants (must hold)

These are properties the current build guarantees. Any future refactor must
preserve all of them:

- `onboarding_done='true'` in Hive → app never reopens onboarding.
- Hive box `lise_ai_v1` is opened once at boot, never reopened concurrently.
- `connectivityService` is a singleton; only one timer at a time.
- `CrashReporter.instance` is the only crash hub; only one
  `FlutterError.onError` handler installed.
- Streaming sessions are tied to a single `AnthropicService.streamMessage`
  call; cancel on widget dispose.
- Telemetry queue is bounded at 500 events.
- PDF render handle is closed via `_doc.close()` after use.

---

## 7. Open questions

- Should we run analyzer on every commit via a git hook? (Currently manual.)
- Should `RuntimeStabilityMonitor` ship in release builds, or be gated to
  `kDebugMode` only? Current decision: ship in release, but the diagnostics
  screen itself stays dev-only.
- Long-term memory persistence format: JSON in Hive vs. SQLite when we
  cross 10 000 users? Defer until needed.
