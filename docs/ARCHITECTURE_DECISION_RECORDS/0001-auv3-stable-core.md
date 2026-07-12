# ADR 0001: AUv3 is the stable host core

- Status: accepted
- Date: 2026-07-12

Use an AUv3 effect as the reliable Logic integration and keep project editing out of
the core. Apple documents AUv3 as the current model and AUv2 as maintenance mode.
The AU receives its own audio buses, callbacks, parameters and persistent state but
not a general Logic project object model. The product therefore remains useful when
all deeper automation is disabled.
