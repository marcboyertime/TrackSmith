# ADR 0002: Shared native Swift core with a C atomic shim

- Status: accepted for foundation; revisit DSP hot paths after profiling
- Date: 2026-07-12

Use Swift packages for schema, state, planning, analysis and initial DSP, plus a tiny
C11 atomic target for macOS 14 compatibility. This keeps Codable and app integration
simple while allowing deterministic offline tests. The AU will use borrowed buffer
views rather than `AudioBuffer` arrays; measured callback performance will decide
whether individual kernels move to C++/Accelerate.
