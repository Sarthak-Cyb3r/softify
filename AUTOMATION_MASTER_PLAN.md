# Softify Autonomous Integration Master Plan (v3.0.7)

**Supreme Authority**: Reverse-Engineer-Anything (`reverse-engineer-anything`) & Chief of Staff / Agents Orchestrator (`agency-agents-orchestrator`)  
**Status**: Ready for Automated Execution  
**Target Workspace**: `/home/sarthak/Desktop/Projects/softify`  
**Reference Codebase**: `/home/sarthak/Desktop/Projects/SimpMusic`  

---

## 🏛️ Command & Control Architecture

The system operates under a dual-supreme command:
- **`reverse-engineer-anything`**: Supreme Architectural & Intelligence Authority (dictates system invariants, reference specs, and design compliance).
- **`agency-agents-orchestrator`** (with Chief of Staff): Supreme Pipeline Commander (manages task dispatches, subagent execution loops, QA gates, and git commits).

```
                    ┌──────────────────────────────────────────────┐
                    │          Reverse-Engineer-Anything           │
                    │       & Chief of Staff / Orchestrator        │
                    │             (Supreme Authority)              │
                    └──────────────────────┬───────────────────────┘
                                           │
         ┌─────────────────────────────────┼─────────────────────────────────┐
         ▼                                 ▼                                 ▼
┌──────────────────┐             ┌──────────────────┐             ┌──────────────────┐
│   Backend Lead   │             │   Mobile Lead    │             │   Frontend Lead  │
│(backend-architect│             │(mobile-app-build/│             │(frontend-develop/│
│senior-developer) │             │senior-developer) │             │ui-designer)      │
└────────┬─────────┘             └────────┬─────────┘             └────────┬─────────┘
         │                                │                                │
         └────────────────────────────────┼────────────────────────────────┘
                                          │
                                          ▼
                                ┌──────────────────┐
                                │ Quality Gates    │
                                │ (reality-checker/│
                                │evidence-collector│
                                └──────────────────┘
```

---

## 📋 Execution Pipeline & Task Delegation

### Phase 1: Core Playback & Listen Together (Sprint 1)
- **Task 1.1**: Metroproto Wire Fix & Intent Synchronization
  - *Agent*: `agency-senior-developer`
  - *Files*: `lib/services/sync/listen_together_service.dart`, `lib/services/sync/listen_together_protocol.dart`
  - *Invariants*: Pre-load intent `playWhenReady=true`, override server default `IsPlaying=false` on `change_track`, suppress crossfade, 750ms drift seek tolerance.
- **Task 1.2**: Mini Player Z-Index & Inset Clearance
  - *Agent*: `agency-frontend-developer`
  - *Files*: `lib/presentation/` (Listen Together join view)
  - *Invariants*: Dynamic padding clearing floating player bar.
- **Task 1.3**: Audio Handler State Conflation & EOF Rewind
  - *Agent*: `agency-mobile-app-builder`
  - *Files*: `lib/services/softify_audio_handler.dart`, `lib/services/audio_clock_service.dart`
  - *Invariants*: Cancel previous progress/buffer tickers on track swap; `pointAtFirstItemIfUnset()` on EOF play; clamp negative timeline emissions.
- **Gate 1**: `agency-evidence-collector` verifies Moto g34 playback logs, absence of stuck loading spinners, and room join playback sync.

### Phase 2: DJ Automix & DSP Calibration (Sprint 2)
- **Task 2.1**: Symmetrical Dual-Trigger DJ Crossfade
  - *Agent*: `agency-senior-developer`
  - *Files*: `lib/services/automix_service.dart`
  - *Invariants*: Trigger on both position polling and EOF event; commit incoming track on mid-fade seek; isolate crossfade software volume from user slider.
- **Task 2.2**: Sleep Timer Cosine Ramping & AutoEq Integration
  - *Agent*: `agency-backend-architect`
  - *Files*: `lib/services/dsp/autoeq_service.dart`, `lib/services/alarm/`
  - *Invariants*: 5s cosine volume attenuation with 800ms silence tail before pause; AutoEq index parser mapped to 10-band ISO peaking biquads.
- **Gate 2**: `agency-reality-checker` audits DSP transfer functions and volume integrity.

### Phase 3: Lyrics & Stream Extractor Resilience (Sprint 3)
- **Task 3.1**: Request ID Tagging & Lyrics Cancellation
  - *Agent*: `agency-frontend-developer`
  - *Files*: `lib/services/lyrics/lyrics_provider_registry.dart`
  - *Invariants*: Monotonic request tokens; discard stale track responses; frame-clock sweep playhead (150ms spring constant).
- **Task 3.2**: 3-Tier YouTube Stream Extractor & 403 CDN Defense
  - *Agent*: `agency-backend-architect`
  - *Files*: `lib/services/stream_telemetry_service.dart`
  - *Invariants*: Itag 774 (Opus 256k) ↔ Itag 141 (AAC 256k) stream twins; PipePipe remote fallback on CDN 403.
- **Gate 3**: `agency-evidence-collector` verifies lyrics update cleanly across 10 rapid track skips.

### Phase 4: Database Maintenance & Release Staging (Sprint 4)
- **Task 4.1**: Safe Orphan Cascade & Vacuum Engine
  - *Agent*: `agency-backend-architect`
  - *Files*: `lib/data/`
  - *Invariants*: Ordered deletion preserving liked and downloaded tracks; WAL checkpoint + vacuum.
- **Task 4.2**: Integration Build & Git Commit
  - *Agent*: `agency-agents-orchestrator`
  - *Invariants*: Commit code cleanly without building APK/Release unless requested.

---

## 🚦 Execution Command for Tomorrow

To trigger full autonomous execution across all specialist agents, simply instruct:
```text
/agency-agents-orchestrator Execute AUTOMATION_MASTER_PLAN.md end-to-end.
```
