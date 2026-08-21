# Coverage Report

Package 5 contains **240** canonical records, **5,280** user phrasings, **720** multi-turn scenarios, and **1,200** retrieval/response evaluations.

## Canonical coverage

| Subdomain | Records | Representative scope |
|---|---:|---|
| `fundamentals` | 24 | Static versus dynamic decisions, automation versus processing/arrangement, macro/micro workflow, listening and stopping |
| `automation_modes` | 24 | Read, Touch, Latch, Write, Trim, Relative, Off, controller writing and safety |
| `track_region` | 30 | Track/region ownership, conversion, moving, alternatives, loops, recording and reuse |
| `editing` | 28 | Points, selections, curves, snapping, Event List, lanes, density, deletion and fine adjustment |
| `level_rides` | 28 | Vocal/instrument rides, section balance, words/breaths, bus/output fades, preserving performance dynamics |
| `sends_effects` | 28 | Delay throws, reverb sends, send/return control, tails, ducking, bypass, pan/width and creative motion |
| `plugin_parameters` | 24 | EQ/compressor/saturation/modulation automation, parameter exposure, Smart Controls, latency and mode switches |
| `midi_controllers` | 20 | Automation Quick Access, MIDI CC, mod wheel, pitch bend, hardware control, jitter and recording ownership |
| `buses_groups` | 16 | Bus versus member automation, VCAs, groups, parallel paths, Track Stacks, Stereo Out and Master distinctions |
| `troubleshooting` | 18 | Snap-back, hidden lanes, accidental overwrite, wrong parameter, timing, cycle edges, bounce mismatch and Low Latency Mode |

## Supporting coverage

- 36 explicit disagreements preserve context rather than forcing a universal rule.
- 44 myths and anti-patterns target common beginner failure modes.
- 240 claim, strategy, and procedure candidates maintain one-to-one canonical provenance.
- 100 compact retrieval tests span all ten subdomains.

## Known gaps

- Candidate records have not received final TrackSmith human review.
- Candidate Logic paths have not all been exercised in the owner’s installed Logic build.
- Reddit is represented only by bounded public discovery seeds, not bulk API acquisition.
- The package does not contain audio fixtures proving artistic usefulness.
- Third-party plug-in parameter exposure varies by plug-in/version.
