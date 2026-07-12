# Architecture

## Decision summary

The production core is an AUv3 effect plus a native companion app. A linear,
versioned graph is shared by real-time and offline renderers. Logic control is a
separate capability-gated adapter. AUv2 is not the starting point: Apple describes
AUv2 as maintenance mode and recommends AUv3 for new development.

```text
Logic Pro host process                 Companion app process
┌───────────────────────────┐          ┌─────────────────────────────┐
│ AUv3 extension            │          │ Conversation / waveform     │
│ ┌───────────────────────┐ │ App      │ history / references        │
│ │ RT: compiled DSP graph│ │ Group    │                             │
│ │ + bounded ring writer │◄├─────────►│ planner + preview service   │
│ └──────────┬────────────┘ │ messages │ snapshot store + providers  │
│ non-RT: snapshot reader   │          └─────────────┬───────────────┘
└────────────┼──────────────┘                        │ optional
             │ audio passing through insert          ▼
             │                           ┌─────────────────────────────┐
             └──────────────────────────►│ Logic adapter               │
                                         │ MIDI stable-ish / AX exp.  │
                                         └─────────────────────────────┘

Offline tools use the same PlanSchema + DSPCore + AudioAnalysis modules.
```

The package-built `AuditionApp` is the first working native companion slice. It
loads a validated preview-session manifest and runs original plus all valid variants
simultaneously through one `AVAudioEngine`; gain selection makes A/B changes without
losing sample position. It remains separate from the signed App Group/plug-in app.

## Process and trust boundaries

- The AU extension receives only its buses and host-supplied callbacks. It does not
  receive a Logic project object model.
- The companion owns network/provider access, secrets, disk cache, UI, and heavy
  analysis. No provider is trusted to produce executable actions.
- App Group membership is the intended signed sharing boundary. The implemented
  `FileExchange` proves atomic JSON exchange in two local processes; signed App
  Group resolution and notification/socket wake-up still require Xcode validation.
- Accessibility and control-surface actions are separate transactions with explicit
  preconditions and postcondition verification. They never mutate the DSP core.

## Render-thread contract

The render callback may read atomically published scalar parameters, pull audio,
process a precompiled graph in preallocated storage, and copy bounded samples to a
preallocated ring. It must not allocate, lock, log, access files, call a model,
perform IPC, or touch UI. Plan compilation, ring snapshots, FFT/DFT analysis,
preview rendering, serialization, and graph swaps are non-real-time work.

The current offline `CompiledGraph` uses preallocated node state but the public
`AudioBuffer` owns Swift arrays; the AU adapter must bind host buffers directly to a
separate render view before the shared graph can be called from Logic. That adapter
is an explicit open item, not an assumed real-time guarantee.

## State flow

```text
request → goals/prohibitions → current analysis → proposed plan
        → validation → offline render → measurements/guardrails
        → preview snapshot → user commit → atomically published compiled graph
```

Snapshots are immutable and parent-linked. The committed AU graph is never replaced
until a candidate validates and compiles. A failed provider, render, IPC request, or
save leaves the prior committed graph live. AU `fullStateForDocument` will persist
the committed plan and snapshot metadata; preview audio remains a managed cache.

## Failure recovery

- Invalid or stale plans are rejected before compilation.
- Unsupported DSP nodes produce typed errors; the committed graph remains active.
- NaN/infinity output is replaced with zero and bounded; a production build will
  add an atomic fault counter visible outside render.
- IPC messages are immutable files written temp-then-rename; partial files are not
  presented as valid messages.
- Experimental Logic actions stop at the first unverifiable postcondition and
  record observed before/after state plus the recovery attempt.

## Provider path

Providers return typed goals or plans to `AgentCore`; they do not receive shell,
filesystem, host, plug-in, or arbitrary network tools. A deterministic provider is
always available. Audio upload, if later implemented, requires a separate explicit
consent transaction and a provider-specific disclosure.

## Research-informed optimization boundary

Reference matching and candidate refinement may later run a bounded gradient-free
search over the same deterministic graph. It is companion/offline work: choose a
validated graph, render candidates, measure independent trait/penalty objectives,
cache by graph/source hash, and return previews. An effect-sensitive representation
must be calibrated against listening tests; a generic semantic embedding is not a
production-quality oracle. Generative waveform editing remains a separate opt-in
new-asset transaction, never a hidden graph node.
