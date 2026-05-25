# OmniCore AI Engine — Migration Analysis & Plan

**Version**: 1.0.0
**Date**: 2026-05-25
**Status**: analysis only — no code changes
**Goal**: extract the LiseAI AI infrastructure into a reusable, multi-vertical
"OmniCore AI Engine" without breaking the working LiseAI build.

---

## 0. TL;DR

| | |
|---|---|
| **Codebase scope** | 74 services, 12 models, 6 core, 15 widgets, 9 screens, 7 backend adapters — 15 043 LOC just in services |
| **Truly domain-agnostic right now** | ~6 services (logger, version, connectivity, crash reporter, api_client, working_memory) — extractable in week 1 |
| **Lightly LiseAI-tinted, easy to decouple** | ~20 services (memory cluster, voice cluster, vision, sync, observability, telemetry) |
| **Hard LiseAI-domain — stay in app** | ~40 services (pedagogy, lessons, teacher persona, learning graph, exam camp, study analytics, board widgets) + all screens |
| **Currently coupled-to-Claude-only** | `anthropic_service.dart` (495 LOC). No OpenAI/Gemini abstraction exists yet — must introduce an `AIProvider` interface before the engine can be cross-provider |
| **Highest-risk coupling** | `LessonMode` enum + `StudentLevel` enum imported in 12+ services; storage box name `lise_ai_v1` hardcoded; singletons hold app state |
| **Recommended structure** | Dart workspace monorepo with `packages/omnicore_*` libraries; LiseAI app becomes a thin consumer of those packages plus its own `lib/liseai/` domain layer |
| **Migration shape** | 8 phases over ~6–8 weeks, every phase ships a green TestFlight build, no big-bang refactor |

---

## 1. Inventory — what's there today

### 1.1 Counts

| Folder | Files | LOC (approx) |
|---|---|---|
| `lib/services/` | 74 | 15 043 |
| `lib/services/adapters/` | 7 | (counted above) |
| `lib/models/` | 12 | — |
| `lib/core/` | 6 | — |
| `lib/widgets/` | 15 | — |
| `lib/screens/` | 9 | — |
| `docs/` | 5 (4 QA + 1 perf) | — |

### 1.2 Largest services (LOC)

| LOC | File |
|---:|---|
| 542 | realtime_voice_engine.dart |
| 495 | anthropic_service.dart |
| 485 | teacher_engine.dart |
| 453 | learning_graph_engine.dart |
| 435 | live_lesson_service.dart |
| 413 | teacher_pen_engine.dart |
| 369 | streaming_teacher_session.dart |
| 369 | runtime_validation_service.dart |
| 341 | runtime_stability_monitor.dart |
| 330 | pedagogy_engine.dart |
| 329 | lesson_flow_engine.dart |
| 319 | semantic_memory.dart |
| 309 | work_analysis_service.dart |
| 302 | supabase_sync_service.dart |
| 301 | long_term_memory.dart |

Most of the heavy mass is **teacher/lesson/pedagogy** — that stays in LiseAI. The reusable AI core sits in the smaller files: memory cluster (~1 100 LOC total), voice cluster (~900 LOC), Claude transport (separable subset of anthropic_service), vision (~600 LOC), observability/sync (~1 500 LOC).

---

## 2. Classification by extractability

Each service is tagged with one of five labels:

- **F** — Foundation: zero domain coupling, extract as-is.
- **C** — AI Core: provider/protocol code, extract after small surgical decoupling.
- **M** — Mixed: half generic + half LiseAI logic, split in two.
- **D** — Domain: LiseAI-specific, stays in app.
- **B** — Backend/Sync: extract under a separate Storage/Sync package.

### 2.1 Full service classification

| Tag | File | Why |
|---|---|---|
| F | app_logger.dart | debug printer, no domain |
| F | app_version_service.dart | reads bundle version |
| F | connectivity_service.dart | DNS-lookup ping |
| F | crash_reporter.dart | backend interface + no-op default |
| F | error_handler.dart | enum of error types; comments mention LiseAI but the enum is generic |
| F | api_client.dart | HTTP retry/backoff/timeout policies |
| F | haptics_service.dart | platform haptics passthrough |
| F | silence_detector.dart | audio level threshold |
| F | speech_service.dart | STT wrapper around `speech_to_text` package |
| F | runtime_stability_monitor.dart | added in the QA phase; pure observability |
| F | runtime_validation_service.dart | active suite over the monitor + storage + connectivity |
| F | storage_service.dart | Hive key-value box — only LiseAI-ish part is the box name `lise_ai_v1` |
| F | working_memory.dart | pure data class for goals + cognitive load |
| C | anthropic_service.dart | **split candidate**: streaming HTTP/SSE (C) + buildSystemPrompt (D) + _wbSystemPrompt (D) |
| C | ai_cost_tracker.dart | token/cost counters, mostly generic; uses model price constants for Claude only |
| C | streaming_teacher_session.dart | wraps anthropic streaming; couples to PacingProfile + SpeechTagParser → split candidate |
| C | api_client.dart (listed above) | same |
| C | telemetry_service.dart | bounded queue + event types — values are LiseAI-named (lessonStarted, confusionSpike…) so enum needs decoupling |
| M | long_term_memory.dart | imports only storage_service; entities are SubjectMastery + MistakePattern — generalize to `DomainMastery` + `MistakePattern<T>` |
| M | short_term_memory.dart | couples to `TeacherEmotionalState` + `attention_engine.PacingAdjustment` — generalize to `AssistantEmotionalState` |
| M | working_memory.dart (already F) | — |
| C | episodic_memory.dart | imports storage + lesson_mode → swap lesson_mode for a generic `EpisodeKind` enum |
| C | semantic_memory.dart | imports storage_service only; perfectly suited for OmniCore knowledge graph |
| C | memory_summarizer.dart | uses Claude; LiseAI prompt baked in → swap prompt with provider-agnostic memory-summarization prompt |
| C | memory_retrieval_engine.dart | clean orchestrator over the 5 memory layers |
| C | memory_prompt_layer.dart | builds the "memory context block" that goes into the system prompt — generic shape, LiseAI-flavoured wording |
| C | session_recovery_service.dart | snapshot + restore on relaunch (generic) |
| C | session_continuity_service.dart | usedAnalogies / topic context — LiseAI-tinted; refactor to a `SessionContext<T>` |
| C | visual_reasoning_engine.dart | Claude Vision call wrapper; ImageAnalysisResult has LiseAI-flavoured VisualContentType (question/theory/mistake) but it's a thin enum |
| C | pdf_service.dart | pdfx wrapper, perfectly generic |
| C | work_analysis_service.dart | grades student work via Claude — heavy LiseAI prompt; split into vision orchestrator + LiseAI prompt builder |
| C | teacher_voice_service.dart | TTS playback via audioplayers; only the *name* is domain-flavoured |
| D | realtime_voice_engine.dart | 542 LOC, deeply couples to LessonMode + LiseAI persona |
| D | voice_command_detector.dart | LiseAI-specific command vocabulary |
| F | voice_playback_queue.dart | generic audio queue |
| B | supabase_sync_service.dart | offline-first sync queue (Phase-1 capable extraction) |
| B | sync_queue.dart | generic queue primitive |
| B | sync_repository.dart | generic repo interface |
| B | backend_provider_service.dart | provider abstraction + state machine |
| B | adapters/*.dart (7 files) | Firebase + Supabase concrete implementations |
| B | auth_service.dart | wraps Supabase auth |
| F | scenario_runner.dart | health checks; values are LiseAI-named but the runner shape is generic |
| F | stress_test_runner.dart | synthetic stress simulator |
| F | release_validator.dart | release-readiness checks; LiseAI-tinted detail strings |
| D | teacher_engine.dart | LiseAI persona, pedagogy |
| D | teacher_identity_service.dart | TeacherPersonalityType |
| D | teacher_pen_engine.dart | chalk drawing engine — could be promoted to OmniCore Canvas |
| D | board_redraw_service.dart | Claude→WhiteboardElement JSON converter, uses LiseAI prompts |
| D | chalk_sound.dart | sound effects for the board |
| D | pedagogy_engine.dart | LiseAI lesson construction |
| D | cognitive_profile_engine.dart | StudentMastery, CompetenceCurve |
| D | learning_graph_engine.dart | Turkish high-school curriculum graph |
| D | learning_journal_service.dart | study journal entries |
| D | lesson_flow_engine.dart | LessonFlow state machine |
| D | lesson_transition_service.dart | LessonMode transitions |
| D | live_lesson_service.dart | live "Sesli Ders" mode (435 LOC) |
| D | exam_camp_service.dart | Sınav Kampı feature |
| D | streak_service.dart | gamification |
| D | achievement_service.dart | gamification |
| D | study_analytics_service.dart | StudentProfile-flavoured analytics |
| D | profile_service.dart | StudentProfile bridge |
| D | demo_service.dart | LiseAI demo content |
| D | simulation_engine.dart | LiseAI scenario tester |
| D | ambient_engine.dart | UI ambient state (LiseAI mode-flavoured) |
| D | attention_engine.dart | PacingAdjustment, ConfusionSignal |
| D | human_pacing_engine.dart | LiseAI lesson pacing logic |
| D | notification_engine.dart | LiseAI notifications |
| D | ui_state_engine.dart | LiseAI UI state machine |
| D | local_analytics_service.dart | local analytics, LiseAI events |

### 2.2 Score

| Bucket | Count |
|---|---:|
| **F** (foundation, extract today) | 13 |
| **C** (AI core, decouple lightly first) | 14 |
| **M** (mixed, split) | 2 |
| **B** (backend/sync extraction) | 12 |
| **D** (LiseAI domain, stay in app) | 33 |
| Total | 74 |

---

## 3. Answers to the 12 numbered questions

### 3.1 Hangi dosya ve servisler LiseAI'ye özel?
The 33 **D**-tagged services above plus:
- All `lib/screens/` (every screen is LiseAI UI)
- Most `lib/widgets/` (lesson_board_page, voice_conversation_page, visual_overlay, analytics_panel, exam_camp_overlay, achievement_toast, session_recap_card, atmosphere_layer, ambient_layer, orb_renderer, live_subtitle_engine, math_markdown, visual_correction_layer — all LiseAI-flavoured)
- LiseAI models: `lesson_mode.dart`, `lesson_flow.dart`, `lesson_timeline.dart`, `student_profile.dart`, `teacher_identity.dart`, `cognitive_profile.dart`, `learning_journal.dart`, `whiteboard_element.dart`, `speech_tag.dart`, `correction_annotation.dart`
- LiseAI config: `core/feature_flags.dart`, `core/app_constants.dart`

### 3.2 Hangi dosya ve servisler ortak AI çekirdeği olarak ayrılabilir?
The 13 **F** + 14 **C** + 2 **M** + 12 **B** services = **~41 services** are extractable, after light surgery. The "agnostic now" set (6 services) needs no surgery at all.

### 3.3 Memory sistemi nerede?
- Five layers in `lib/services/`:
  - `working_memory.dart` (active goals, cognitive load)
  - `short_term_memory.dart` (current session — couples to TeacherEmotionalState)
  - `long_term_memory.dart` (SubjectMastery, MistakePattern)
  - `episodic_memory.dart` (per-lesson episodes)
  - `semantic_memory.dart` (knowledge graph)
- Three orchestrators:
  - `memory_retrieval_engine.dart` (pulls from all 5)
  - `memory_summarizer.dart` (Claude-powered compression)
  - `memory_prompt_layer.dart` (builds the system-prompt memory block)
- Session continuity:
  - `session_continuity_service.dart` (between-session topic + usedAnalogies)
  - `session_recovery_service.dart` (cold-start restore)

### 3.4 Streaming cevap sistemi nerede?
- Transport: `lib/services/anthropic_service.dart:streamMessage()` — SSE parser, line buffer, event-block decoding.
- Wrapper: `lib/services/streaming_teacher_session.dart` — pacing-aware re-emission, speech tag parsing.
- Consumed by: `screens/ai_os_screen.dart`, `services/realtime_voice_engine.dart`, `services/board_redraw_service.dart`, `services/work_analysis_service.dart`, `services/live_lesson_service.dart`, `services/memory_summarizer.dart`.

### 3.5 Claude/OpenAI/Gemini gibi model entegrasyonları nerede?
Currently **only Claude** in `lib/services/anthropic_service.dart`. No OpenAI/Gemini integration exists yet. The hardcoded values are:
- Endpoint: `https://api.anthropic.com/v1/messages`
- Model: `claude-haiku-4-5-20251001`
- Version header: `anthropic-version: 2023-06-01`

There is **no `AIProvider` abstraction** today. Introducing one is the first prerequisite for OmniCore.

### 3.6 Fotoğraf/PDF/görsel analiz sistemi nerede?
- `lib/services/visual_reasoning_engine.dart` — Claude Vision call, ImageAnalysisResult, VisualSubjectDetector.
- `lib/services/pdf_service.dart` — pdfx page render-to-bytes.
- `lib/services/work_analysis_service.dart` — grading student handwriting (LiseAI prompt).
- `lib/services/board_redraw_service.dart` — generates LessonTimeline JSON from a Vision result (LiseAI prompt).
- `lib/models/image_context_model.dart` — ImageAnalysisResult + VisualContentType enum.
- `lib/widgets/pdf_page_picker.dart` — UI picker.
- `lib/widgets/visual_overlay.dart`, `visual_correction_layer.dart` — overlays on top of submitted images.

### 3.7 Voice, TTS, STT altyapısı nerede?
- STT: `speech_service.dart` (speech_to_text package wrapper)
- TTS: `teacher_voice_service.dart` (audioplayers wrapper with rate control)
- Live voice loop: `realtime_voice_engine.dart` (542 LOC — coordinates STT → AI → TTS)
- Command words: `voice_command_detector.dart`
- Playback queue: `voice_playback_queue.dart`
- Silence: `silence_detector.dart`
- Live captions: `widgets/live_subtitle_engine.dart`

### 3.8 Whiteboard/teacher board sistemi nerede?
- UI: `lib/widgets/lesson_board_page.dart` (913 LOC — `_BoardPainter` + `_DrawingNotifier` + `_TeachingSpeed` + `_TBtn` + `_SpeedChip`)
- Pen: `lib/services/teacher_pen_engine.dart`
- Animation: implicit in `_BoardPainter` (delays + Curves.easeInOut transforms)
- Redraw-from-image: `lib/services/board_redraw_service.dart`
- Sound: `lib/services/chalk_sound.dart`
- Element model: `lib/models/whiteboard_element.dart`
- Timeline: `lib/models/lesson_timeline.dart`
- Entry from chat: `widgets/voice_conversation_page.dart:_openBoard()`, `widgets/visual_overlay.dart:onOpenBoard`

### 3.9 Gelecekte hangi ortak modüller çıkarılmalı?
For Personal AI, Visa/Immigration AI, Legal AI, Health AI, Accounting AI, YouTube content AI:

| OmniCore module | Contents (current files) | Verticals that use it |
|---|---|---|
| `omnicore_foundation` | app_logger, app_version_service, connectivity_service, crash_reporter, error_handler, api_client, haptics_service, storage_service, runtime_stability_monitor, runtime_validation_service | all |
| `omnicore_provider` | AIProvider interface + Claude / OpenAI / Gemini adapters (Claude is `anthropic_service` minus prompts) | all |
| `omnicore_streaming` | streaming_teacher_session refactored to a generic `StreamingSession` | all |
| `omnicore_memory` | the 5 memory layers + 3 orchestrators (generalized via type params: `LongTermMemory<T extends Mastery>`) | personal, legal, health, accounting (visa less so) |
| `omnicore_session` | session_continuity + session_recovery generalized to `SessionContext<T>` | all |
| `omnicore_vision` | visual_reasoning_engine, pdf_service, image_context_model | personal, legal, accounting, YouTube |
| `omnicore_voice` | speech_service, teacher_voice_service (renamed `AssistantVoiceService`), realtime_voice_engine (with persona injection), voice_command_detector, voice_playback_queue, silence_detector, live_subtitle_engine | personal, YouTube (content narration) |
| `omnicore_canvas` | teacher_pen_engine, board_redraw_service, chalk_sound, lesson_board_page extracted to `OmniCanvasPage`, whiteboard_element model | legal (flowcharts), accounting (charts), YouTube (storyboards) |
| `omnicore_sync` | supabase_sync_service, sync_queue, sync_repository, backend_provider_service + adapters/* | all |
| `omnicore_observability` | telemetry_service (generic queue), crash_reporter (already), release_validator, scenario_runner, stress_test_runner | all |
| `omnicore_cost` | ai_cost_tracker (with multi-provider price tables) | all |

Each future vertical (`personal_ai`, `visa_ai`, `legal_ai`, `health_ai`, `accounting_ai`, `youtube_ai`) then becomes a thin app that:
1. Imports the `omnicore_*` packages it needs.
2. Provides a domain prompt builder (replaces LiseAI's `_basePersona` + `_modeInstructions`).
3. Provides domain-specific models (replaces `StudentProfile` / `LessonMode`).
4. Provides domain-specific UI.

### 3.10 En güvenli yeni klasör yapısı ne olmalı?

```
/
├── packages/                              ← OmniCore monorepo workspace
│   ├── omnicore_foundation/
│   │   ├── lib/src/{logger, connectivity, crash, errors, http, hive_box, runtime}/
│   │   └── pubspec.yaml
│   ├── omnicore_provider/
│   │   ├── lib/src/{provider_interface, claude_provider, openai_provider, gemini_provider}/
│   │   └── pubspec.yaml
│   ├── omnicore_streaming/
│   ├── omnicore_memory/
│   ├── omnicore_session/
│   ├── omnicore_vision/
│   ├── omnicore_voice/
│   ├── omnicore_canvas/
│   ├── omnicore_sync/
│   │   └── lib/src/adapters/{supabase, firebase}/
│   ├── omnicore_observability/
│   └── omnicore_cost/
│
├── apps/                                  ← Verticals built on OmniCore
│   ├── liseai/                            ← Today's lise_ai project, slimmed
│   │   ├── lib/
│   │   │   ├── liseai_persona/            ← LiseAI prompt builders
│   │   │   ├── liseai_pedagogy/           ← teacher/lesson/learning engines
│   │   │   ├── liseai_models/             ← StudentProfile, LessonMode etc.
│   │   │   ├── screens/, widgets/
│   │   │   └── main.dart
│   │   └── pubspec.yaml (depends_on omnicore_*)
│   ├── personal_ai/   (future)
│   ├── visa_ai/       (future)
│   ├── legal_ai/      (future)
│   ├── health_ai/     (future)
│   ├── accounting_ai/ (future)
│   └── youtube_ai/    (future)
│
├── docs/
│   └── architecture/omnicore_migration_plan.md   ← this file
├── melos.yaml         ← optional, monorepo orchestrator
└── pubspec.yaml       ← workspace root
```

Why this shape:
- **Pure Dart packages**, not yet pub.dev — using path dependencies inside the monorepo means we can iterate freely without versioning friction.
- **Each `omnicore_*` is independently buildable** (`dart pub get && dart analyze`), so a regression in one package can't take the others down.
- **`apps/liseai/` stays alongside the packages** so the existing working build keeps shipping while extraction happens incrementally.
- **`melos` is optional** — only needed if we want one-command `melos test` across packages. Native `dart pub workspace` (Dart ≥ 3.6) works equally well.

### 3.11 Refactor sırasında kırılma riski olan noktalar nelerdir?

Ordered by severity:

**Critical risk (could break entire build)**

1. **`LessonMode` enum sprayed across 12 services + ai_os_screen + main.dart** — used in switch expressions, system-prompt generation, and as a state key. If we move this model out of `lib/models/` without simultaneously updating every caller, half the codebase fails to compile.
2. **`StudentLevel` enum** — same pattern, used in `buildSystemPrompt(LessonMode, StudentLevel)` and StudentProfile.
3. **`AnthropicService.buildSystemPrompt(...)`** is `static` and called from at least 5 different services. Refactoring this into a `LiseAIPromptBuilder` requires a flag-day update or a temporary adapter shim.
4. **Singleton state machines** — `BackendProviderService.instance`, `SupabaseSyncService.instance`, `RuntimeStabilityMonitor.instance`, `CrashReporter.instance`, `ReleaseValidator.instance`. Their state crosses package boundaries; moving them needs careful interface design so the singleton owner is in one place.
5. **Hive box name `lise_ai_v1` is a private const inside `storage_service.dart`** — once we extract storage into Foundation, the box name has to come from the app, not the package. If we forget, OmniCore would start opening the LiseAI box for every vertical.

**High risk (subtle behaviour changes)**

6. **Streaming SSE parser** — `anthropic_service.streamMessage()` has a hand-rolled line buffer that handles partial chunks. Moving it into a `ClaudeProvider` while preserving exact byte-for-byte behaviour is the kind of thing that breaks in production but passes unit tests.
7. **`FlutterError.onError` handler chain** — currently bridges `CrashReporter` + `RuntimeStabilityMonitor.noteCrash()`. Both will move to `omnicore_observability`, but the registration must happen in `main()` of the app, not in the package.
8. **Hardcoded prompts in `board_redraw_service.dart`, `memory_summarizer.dart`, `work_analysis_service.dart`** — all use Claude; all mix transport + prompt. Split required.
9. **`TeacherEmotionalState` from `models/teacher_identity.dart`** — imported by `short_term_memory.dart`. Memory module can't move until this is generalized to `AssistantEmotionalState` or similar.
10. **`PacingProfile`** in `streaming_teacher_session.dart` — coupled with the system-prompt builder. Generic streaming session can't move until this is parametrized.

**Medium risk**

11. **Backend adapters already implement an interface (`backend_adapters.dart`)** — extraction is straightforward but each adapter pulls its SDK as a transitive dependency. OmniCore Sync must declare these as `dependencies` (not `dev_dependencies`).
12. **`telemetry_service.TelemetryEventType` enum** is LiseAI-named — generalization needs a string-based event type plus a typed factory per vertical.
13. **`feature_flags.dart`** has LiseAI flags hardcoded — needs to become a per-app config injected into OmniCore.
14. **iOS bundle id + entitlements** — each new vertical app is a separate iOS target with its own bundle id, App ID, provisioning profile. Not a code risk but a release-engineering risk.

**Low risk (mechanical)**

15. **Models** like `image_context_model.dart`, `whiteboard_element.dart`, `lesson_timeline.dart` — straight `move + update imports`.
16. **Pure utility services** like `app_logger`, `connectivity_service` — extract with zero changes.

### 3.12 Çalışan sistemi bozmadan adım adım migration planı

See §5 below.

---

## 4. Dependency hotspots (the graph that hurts)

These are the imports whose movement carries the most blast radius. **Do not move any of these in isolation** — they need a coordinated phase.

| Import | Imported by (count) | Notes |
|---|---:|---|
| `services/storage_service.dart` | 20+ | every service that persists anything |
| `services/anthropic_service.dart` | 9 | streaming + prompts + Claude Vision |
| `models/lesson_mode.dart` | 12+ | enum in switch-expressions everywhere |
| `models/student_profile.dart` | 8 | profile + level passed to prompts |
| `core/supabase_config.dart` | 4 | initialization in main + adapter use |
| `models/teacher_identity.dart` | ~5 | TeacherEmotionalState used by short_term_memory |
| `services/runtime_stability_monitor.dart` | 3 (added in QA) | bridge from main.dart + diagnostics + validation |
| `services/connectivity_service.dart` | 3 | the global instance is declared in main.dart |

**Implication for migration order**: storage and LessonMode must be extracted *very* early (in their own phase), because everything else depends on them transitively.

---

## 5. Phased migration plan (the safe sequence)

**Guiding principle**: every phase must end with a **green TestFlight-eligible build**. No "we'll fix it next sprint" allowed mid-phase.

### Phase 0 — Document & freeze (week 0) ✅ this document
- Output: this `omnicore_migration_plan.md`.
- No code touched.
- Snapshot of working build: tag `pre-omnicore-v1` in git.
- Manual QA run from `docs/qa/manual_test_execution.md` recorded as the "known good" baseline.

### Phase 1 — Provider interface (week 1)
- Add `lib/omnicore/provider/ai_provider.dart` (new file, no moves).
- Define `abstract class AIProvider { Stream<String> streamMessage(...); Future<String> sendOnce(...); }`.
- Add `lib/omnicore/provider/claude_provider.dart` — a thin adapter around the existing `AnthropicService` that implements `AIProvider`. **No change to `AnthropicService` itself.**
- Update **one** caller (`memory_summarizer.dart`) to consume `AIProvider` instead of `AnthropicService` directly, as a proof point.
- Build: `flutter build ios --release`, `flutter build macos --release`.
- Risk: low. Existing code untouched, only an additive interface.

### Phase 2 — Internal layering (week 2)
- Create `lib/omnicore/` subtree as a *parallel mirror* of where files will eventually move. Use **barrel files** (`lib/omnicore/foundation.dart`, `lib/omnicore/memory.dart`, …) that re-export from current locations.
- This lets callers start importing `package:lise_ai/omnicore/foundation.dart` instead of individual service files, without any files actually moving yet.
- Migrate `main.dart` and a handful of services to use barrel imports.
- Build: as above.
- Risk: low. Barrel re-exports don't move code, they just establish the future package boundary.

### Phase 3 — Hive box name lift-out + Foundation extraction (week 3)
- Change `StorageService` to take `boxName` in its constructor instead of a hardcoded `_boxName = 'lise_ai_v1'`. Default it to `'lise_ai_v1'` so the existing call site keeps working.
- Extract `app_logger`, `app_version_service`, `connectivity_service`, `crash_reporter`, `error_handler`, `api_client`, `haptics_service`, `storage_service`, `runtime_stability_monitor`, `runtime_validation_service` into `packages/omnicore_foundation/`.
- App pubspec switches to a path dependency `omnicore_foundation: { path: ../../packages/omnicore_foundation }`.
- Build: as above. Run all of `docs/qa/manual_test_execution.md` Section 11 (long session).
- Risk: medium. First time the app depends on an out-of-tree package — pubspec, path resolution, version pinning.

### Phase 4 — Memory + Session extraction (week 4)
- Decouple `TeacherEmotionalState` from `short_term_memory.dart` by introducing `AssistantEmotionalState` in OmniCore; adapt LiseAI's TeacherEmotionalState to extend/wrap it.
- Decouple `LessonMode` from `episodic_memory.dart` by introducing a generic `EpisodeKind` enum.
- Extract the 5 memory layers + 3 orchestrators + 2 session services into `packages/omnicore_memory/` and `packages/omnicore_session/`.
- Build + full manual QA Sections 5, 8 (memory restore).
- Risk: high. Memory bugs are subtle and may only surface after several sessions. Keep the prior version tagged for hot-rollback.

### Phase 5 — Provider split + Streaming + Vision (week 5)
- Extract Claude transport (without the prompt builders) into `packages/omnicore_provider/`. The HTTP + SSE parsing logic is verbatim.
- LiseAI keeps `liseai_prompt_builder.dart` with the original `_basePersona` + `_modeInstructions` + `_latexRules` + `_wbSystemPrompt` strings.
- Extract `streaming_teacher_session.dart` into `packages/omnicore_streaming/` after parametrizing `PacingProfile`.
- Extract `visual_reasoning_engine.dart` + `pdf_service.dart` + `image_context_model.dart` into `packages/omnicore_vision/`. `work_analysis_service.dart` splits: vision call goes to OmniCore Vision, prompt stays in LiseAI.
- Build + full QA Sections 2, 3, 5.
- Risk: high. Streaming SSE byte-handling is the kind of code that fails only under specific network conditions.

### Phase 6 — Voice + Canvas + Sync + Observability (week 6)
- Extract voice cluster (speech, TTS, realtime engine, command detector, queue, silence, subtitle widget) into `packages/omnicore_voice/`. `realtime_voice_engine.dart`'s LiseAI-specific persona is parametrized.
- Extract pen + redraw + chalk + whiteboard element model + the board page (renamed `OmniCanvasPage`) into `packages/omnicore_canvas/`.
- Extract `supabase_sync_service`, `sync_queue`, `sync_repository`, `backend_provider_service`, `adapters/*` into `packages/omnicore_sync/`.
- Extract `telemetry_service` + `release_validator` + `scenario_runner` + `stress_test_runner` into `packages/omnicore_observability/`. Telemetry enum is replaced with a string-based event type plus a per-app typed factory.
- Extract `ai_cost_tracker` into `packages/omnicore_cost/` with multi-provider price tables.
- Build + full QA Sections 4, 6, 7, 9, 10.
- Risk: medium. Each extraction is large but the patterns are now repeated.

### Phase 7 — Slim the app & document the public API (week 7)
- `apps/liseai/` keeps only: LiseAI prompts, pedagogy, lesson, teacher, learning engines, models, screens, widgets.
- `apps/liseai/lib/` now imports `package:omnicore_foundation/…` etc.
- All `omnicore_*` packages get `README.md` with example usage.
- Add `dart doc` generation for the public API of each package.
- Build + full QA across all 11 sections.

### Phase 8 — First second vertical (week 8 — proof of reusability)
- Scaffold `apps/personal_ai/` as a hello-world app that consumes OmniCore.
- A "personal assistant" with text chat + memory + voice — no whiteboard, no curriculum.
- Lines of code budget: < 1 500 LOC for the entire app.
- Smoke-test build for iOS + macOS.
- Risk: low — this is the *test* of the migration, not the migration itself.

---

## 6. Per-vertical fit assessment

Quick lookahead — how much of OmniCore will each future vertical actually use?

| Vertical | foundation | provider | streaming | memory | session | vision | voice | canvas | sync | observability | cost | Domain weight |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|
| **LiseAI** (today) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | high (pedagogy) |
| **Personal AI** | ✅ | ✅ | ✅ | ✅ | ✅ | partial | ✅ | — | ✅ | ✅ | ✅ | medium |
| **Visa/Immigration AI** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (passport/forms OCR) | — | — | ✅ | ✅ | ✅ | high (regulatory KB) |
| **Legal AI** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (contract OCR) | — | ✅ (flowcharts) | ✅ | ✅ | ✅ | very high (case KB) |
| **Health AI** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (rx/lab images) | — | — | ✅ | ✅ | ✅ | very high (safety) |
| **Accounting AI** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (receipts) | — | ✅ (charts) | ✅ | ✅ | ✅ | high (regulatory) |
| **YouTube content/video AI** | ✅ | ✅ | ✅ | partial | — | ✅ (storyboards) | ✅ (narration) | ✅ (storyboards) | ✅ | ✅ | ✅ | medium |

**Insight**: every future vertical uses ≥ 9 of the 11 OmniCore packages. The extraction effort amortizes well.

---

## 7. Things explicitly NOT in this plan

- **No move-by-move rename file lists.** Those will be generated as a checklist when each phase starts, not in this document. Putting them here would freeze decisions that should be made when the previous phase's lessons are in hand.
- **No "delete LiseAI" plan.** LiseAI stays the flagship vertical and ships independently. OmniCore exists *to support it*, not to replace it.
- **No Dart-to-other-language port.** OmniCore stays Dart/Flutter; iOS-only release pipeline.
- **No pub.dev publication.** Until the second vertical (`personal_ai`) actually works, all packages stay private to the monorepo via path dependencies.
- **No CI changes in Phase 0-2.** CI updates happen once package structure stabilizes around Phase 3.

---

## 8. Open decisions (need your call before Phase 1 starts)

1. **Monorepo orchestrator**: native `dart pub workspace` (Dart 3.6+) vs `melos`? Recommendation: native; melos only if we eventually need cross-package scripts.
2. **Package naming convention**: `omnicore_foundation` vs `omnicore.foundation` vs `oc_foundation`? Recommendation: `omnicore_foundation` (matches Dart conventions, readable).
3. **Multi-provider strategy**: ship Claude only in OmniCore v1, or include OpenAI/Gemini stubs from day one? Recommendation: Claude only at first; add others when a vertical actually needs them.
4. **Should LiseAI prompts (Turkish, education-focused) be a separate package `liseai_prompts` or stay inline in the app**? Recommendation: stay inline. The prompts are the LiseAI product, they're not reusable.
5. **Stability target**: ship Phase 3 + 4 to TestFlight, or only ship after the full Phase 7? Recommendation: ship at each phase boundary — it forces the "no breaking" rule.
6. **Bundle id strategy for verticals**: `com.gokcerodop.liseai`, `com.gokcerodop.personalai`, `com.gokcerodop.visaai`, …? Or one umbrella `com.gokcerodop.omnicore.<vertical>`? Recommendation: per-vertical top-level bundle id (simpler App Store Connect setup).

---

## 9. Migration go/no-go checklist (apply before each phase ships)

- [ ] All commands in `docs/qa/manual_test_plan.md` Sections 1–11 PASS on the most recent build
- [ ] `flutter analyze` ≤ baseline + 0 new errors/warnings
- [ ] `flutter build macos --release` clean
- [ ] `flutter build ios --release --no-codesign` clean
- [ ] `flutter run --release` on physical iPhone — app boots, no crash for 5 min idle
- [ ] Diagnostics screen → Doğrulama Süitini Çalıştır → all checks ≥ PASS or known WARN
- [ ] Hive box opens without lock errors
- [ ] Memory restore works across cold-restart (Section 5 manual test)
- [ ] Git tag created: `omnicore-phase-N-shipped`

---

## 10. Appendix — pubspec dependency surface (current LiseAI)

```yaml
dependencies:
  flutter: { sdk: flutter }
  cupertino_icons: ^1.0.8
  http: ^1.x          # used by anthropic_service
  hive_flutter: ^1.1  # used by storage_service
  speech_to_text: ^7  # used by speech_service
  audioplayers: ^6    # used by teacher_voice_service
  pdfx: ^2            # used by pdf_service
  file_picker: ^8     # used by main.dart upload
  desktop_drop: ^0.5  # macOS drag-drop
  supabase_flutter: ^2  # used by supabase config + adapters
  flutter_dotenv: ^5  # used by main.dart .env load
  flutter_markdown: ^0.7  # used by chat rendering
```

Each OmniCore package will declare a tight subset. Foundation needs only `hive_flutter` + http + flutter; Provider needs `http`; Voice needs `speech_to_text` + `audioplayers`; Vision needs `pdfx`; Sync needs `supabase_flutter` (and later optionally `firebase_*`).

---

**End of plan.** No code has been changed by writing this document. Once you approve, Phase 1 (provider interface) is the smallest, safest first step.
