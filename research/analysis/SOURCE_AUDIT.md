# Research source and archive audit

This is the reproducible coverage ledger for the user-supplied corpus as observed on 2026-07-12. It separates archive integrity, payload availability, content-hash deduplication, and review depth. A source being present or indexed does **not** mean it received a full-text engineering review.

## Review-depth vocabulary

- **Core**: full-text engineering review, with relevant equations, methods, limitations, and implementation consequences checked.
- **Supporting**: abstract, method, results, limitations, and conclusion reviewed for a bounded product question. This is not a page-by-page review.
- **Peripheral**: systematic relevance screening only. This is not a deep review.
- **Non-evidence**: a supplied synthesis or commentary source that may aid navigation but is not treated as independent research evidence.
- **Gap**: the source slot exists in the manifest, but no usable payload was supplied.

The 61 unique PDF payloads in that supplied 2026-07-12 snapshot divide into **20 Core, 33 Supporting, and 8 Peripheral**. Therefore, 41 unique PDFs in the snapshot have a valid disposition but have **not** received Core-depth full-text review. Any claim that every supplied paper was already read deeply would be false. Later manifest-driven additions are tracked separately in `TRACKSMITH_PRODUCER_JUDGMENT_EXPANSION.md`.

## Archive integrity and extraction equivalence

Each ZIP passed `unzip -t`. Every non-directory member was read from the archive, SHA-256 hashed, and compared with the expected file under `research/extracted/<archive-stem>/`. No user research payload was modified.

| Archive | Members | Hash-matched | Missing | Mismatched |
|---|---:|---:|---:|---:|
| Audio_Production_Papers_and_Standards.zip | 16 | 16 | 0 | 0 |
| TTA-Bench part 01, items 001-015 | 18 | 18 | 0 | 0 |
| TTA-Bench part 02, items 016-017 | 5 | 5 | 0 | 0 |
| TTA-Bench part 03, items 018-030 | 16 | 16 | 0 | 0 |
| TTA-Bench part 04, items 031-044 | 17 | 17 | 0 | 0 |
| TTA-Bench part 05, items 045-062 | 21 | 21 | 0 | 0 |
| TTA-Bench part 06, items 063-067 | 8 | 8 | 0 | 0 |
| TTA-Bench part 07, items 068-070 | 6 | 6 | 0 | 0 |
| TTA-Bench part 08, items 071-081 | 14 | 14 | 0 | 0 |
| TTA-Bench part 09, item 082 | 4 | 4 | 0 | 0 |
| **Total** | **125** | **125** | **0** | **0** |

The 125 archive members contain 97 unique byte payloads: 15 curated PDFs plus one curated README, 82 TTA source slots collapsing to 70 unique payload hashes, and 27 repeated TTA metadata files collapsing to 11 unique payload hashes. The extracted part-01 tree contains one extra `.DS_Store` that is not an archive member; it is irrelevant and remains untouched.

All nine TTA copies of `source_index.csv` have the same SHA-256 digest. All nine copies of `notebooklm_backup_manifest.json` also match one another. The per-part README files are intentionally distinct.

## Index coverage

- PDF: 88 paths, 61 unique hashes; all 61 have valid `pdfinfo` page counts and non-empty `pdftotext` output.
- HTML: 25 paths, 23 unique hashes; 22 unique hashes are usable and one is the empty-file hash shared by slots 074 and 075.
- Supplied source TXT: 2 paths, 2 unique usable hashes. These are now recorded by `source-text-index.tsv` rather than being silently omitted.
- TTA source manifest: all 82 numbered slots exist at the named extracted path. Formats are 56 PDF, 24 HTML, and 2 TXT.

The untracked `research/papers/TTA-Bench-sources-part-02-items-016-to-017/` directory adds one PDF path and one HTML path, but both are byte duplicates of indexed extracted payloads. It is user-owned, remains untouched, and is intentionally outside commit scope.

## TTA source-slot ledger

Every numbered slot in the common `source_index.csv` is listed below. “Duplicate” means byte-identical to another numbered slot, not merely the same title.

| Slot | Format/payload | Review depth | Explicit disposition |
|---:|---|---|---|
| 001 | PDF; duplicate of 069 | Peripheral | Persian MusicGen; cultural/domain-bias evidence, no stable-MVP dependency. |
| 002 | PDF; duplicate of 070 | Supporting | Large-audio-language-model survey; provider calibration and trust limits. |
| 003 | PDF | Supporting | Speech-LLM survey; task-specific evaluation and modality limitations. |
| 004 | HTML | Peripheral | AI-mastering-detector abstract; detection artifacts are not quality targets. |
| 005 | PDF | Core | AI-assisted production user study; revision, DAW integration, and preservation requirements. |
| 006 | PDF | Supporting | AIR-Bench publication variant; comprehension benchmark limits. |
| 007 | PDF | Supporting | AIR-Bench ACL publication variant; distinct payload, same source family. |
| 008 | HTML | Supporting | AIR-Bench project capture; implementation context only. |
| 009 | HTML | Supporting | AUDIT project page; future offline asset editing only. |
| 010 | PDF; duplicate of 011 | Supporting | AUDIT paper; instruction/input/output triplets and preservation. |
| 011 | PDF; duplicate of 010 | Supporting | AUDIT duplicate download. |
| 012 | PDF | Core | FAD adaptation; embedding, sample-size, and reference sensitivity. |
| 013 | PDF; duplicate of 073 | Core | Foundation-model audio-editing survey; separate change, preservation, naturalness, and adherence. |
| 014 | PDF | Supporting | Non-rigid prompts; resolve editable and preserved attributes. |
| 015 | PDF | Supporting | Audio-language-model systematic survey; typed, calibrated tools. |
| 016 | PDF | Supporting | AudioDER; benchmark deduplication and contamination awareness. |
| 017 | HTML | Supporting | AudioLDM 2 documentation; future provider context, not production DSP evidence. |
| 018 | PDF; duplicate of 063 | Supporting | AudioLDM 2 paper; future generation/editing provider. |
| 019 | HTML | Supporting | AudioLDM project page; model context only. |
| 020 | PDF | Supporting | Human-preference metric benchmark; correlations vary by quality dimension. |
| 021 | HTML | Supporting | DAC documentation; future representation/transport context. |
| 022 | PDF | Supporting | DAC-JAX; codec implementation context outside real-time core. |
| 023 | TXT fallback | Core via recovery | Deep Learning and Intelligent Audio Mixing; usable full paper is supplied separately as WIMP 2017 PDF. |
| 024 | HTML | Supporting | Descript Audio Codec repository; future representation context. |
| 025 | PDF | Supporting | Objective speech-quality metrics for codecs; not validated as music-production judges. |
| 026 | HTML | Peripheral | FlowEdit project capture; cross-modal context only. |
| 027 | PDF | Peripheral | Symbolic-music prompting; MIDI generation is an MVP non-goal. |
| 028 | HTML | Peripheral | Symbolic-music paper page; same non-goal. |
| 029 | HTML | Peripheral | Moshi repository; dialogue latency context only. |
| 030 | PDF | Supporting | HAIM; node/snapshot provenance for hybrid workflows. |
| 031 | PDF | Supporting | Human-CLAP; possible ranking feature requiring production calibration. |
| 032 | PDF | Supporting | Large-scale CLAP; semantic alignment is not edit-quality proof. |
| 033 | PDF | Supporting | Audio-mastering comparison; matched data and perceptual evaluation required. |
| 034 | PDF | Peripheral | Score-aware text-to-music training; generation is outside MVP. |
| 035 | PDF | Peripheral | Moshi paper; UX latency context, never render-thread architecture. |
| 036 | TXT synthesis | Non-evidence | Pasted multi-source synthesis. Useful as a navigation aid only; claims must be checked against its cited primary sources. |
| 037 | PDF | Supporting | Music-perception benchmark; test explicit musical tasks rather than assume competence. |
| 038 | PDF | Supporting | MusicGen-Stem; future stem-conditioned generation, outside MVP. |
| 039 | HTML | Supporting | MusicGen benchmark page; web context, not independent quality evidence. |
| 040 | PDF; duplicate of 052 | Supporting | MusicGen paper; future generation and provenance context. |
| 041 | HTML | Supporting | AuditEval repository; candidate preservation/quality evaluation, not validated for the stable DSP graph. |
| 042 | HTML | Supporting | SALMONN-omni poster; model-family context, no direct DSP authority. |
| 043 | HTML | Peripheral | Neural-codec explainer; architectural context only. |
| 044 | HTML | Peripheral | Objective-metrics web capture; candidate tooling, not primary evidence. |
| 045 | PDF | Supporting | Token audio-inpainting paper-page PDF; bounded-gap future module. |
| 046 | PDF; duplicate of 047 | Supporting | Qwen2-Audio report; candidate provider only. |
| 047 | PDF; duplicate of 046 | Supporting | Qwen2-Audio duplicate download. |
| 048 | PDF | Supporting | ViSQOL/PESQ/POLQA robustness; metric rankings vary by degradation. |
| 049 | PDF; duplicate of 050/064/080 | Supporting | SALMONN paper; typed-tool and hallucination constraints. |
| 050 | PDF; duplicate of 049/064/080 | Supporting | SALMONN duplicate download. |
| 051 | PDF | Supporting | SemanticAudio; promising factorization with short-context/proxy-metric limits. |
| 052 | PDF; duplicate of 040 | Supporting | MusicGen duplicate download. |
| 053 | HTML | Peripheral | AI-music detector comparison blog; no architecture-driving evidence. |
| 054 | HTML | Peripheral | Commercial generator comparison blog; no architecture-driving evidence. |
| 055 | PDF | Supporting | TTA-Bench publication version; multidimensional evaluation. |
| 056 | PDF | Supporting | TTA-Bench arXiv version; distinct payload, same source family. |
| 057 | PDF | Supporting | Token audio-inpainting arXiv version; distinct payload, same bounded-gap result family. |
| 058 | PDF | Peripheral | State-space text-to-music training; outside MVP. |
| 059 | PDF | Supporting | Diffusion source separation; expensive and uncertain, outside MVP. |
| 060 | HTML | Peripheral | ViSQOL repository; regression candidate only after music calibration. |
| 061 | PDF | Peripheral | Vision-to-music survey; outside initial scope. |
| 062 | PDF | Core | Automatic mixing with out-of-domain data; domain normalization and professional listening tests. |
| 063 | PDF; duplicate of 018 | Supporting | AudioLDM 2 duplicate download. |
| 064 | PDF; duplicate of 049/050/080 | Supporting | SALMONN duplicate download. |
| 065 | PDF; duplicate of 082 | Peripheral | video-SALMONN; audio-visual reasoning is outside initial scope. |
| 066 | PDF | Supporting | Qwen2.5-Omni; candidate provider only. |
| 067 | PDF | Supporting | Audio ControlNet; future temporal-control editing module. |
| 068 | PDF | Peripheral | Audio-visual foundation-model survey; future multimodal session context. |
| 069 | PDF; duplicate of 001 | Peripheral | Persian MusicGen duplicate download. |
| 070 | PDF; duplicate of 002 | Supporting | Large-audio-language-model survey duplicate download. |
| 071 | PDF | Supporting | Audio-reasoning survey; calibration and task-specific evaluation. |
| 072 | PDF | Supporting | AUDEDIT; future inversion-free offline editor with preservation tests. |
| 073 | PDF; duplicate of 013 | Core | Foundation-model audio-editing survey duplicate download. |
| 074 | empty HTML | Core via recovery | Semantic Scholar capture is empty; item 023 plus the supplied WIMP 2017 PDF recover the same work. |
| 075 | empty HTML | Gap | No supplied Hybrid Transformers payload. Source separation is outside stable MVP; do not claim it was reviewed. |
| 076 | HTML | Peripheral | AudioCraft CLAP-consistency API docs; implementation reference only, not perceptual validation. |
| 077 | HTML | Supporting | AudioLDM 2 diffusers docs; provider integration context. |
| 078 | PDF | Supporting | Wave-U-Net drum mixing; future opaque-baseline comparison. |
| 079 | HTML | Peripheral | CLAP feature-extraction blog; navigation/context only, not primary evidence. |
| 080 | PDF; duplicate of 049/050/064 | Supporting | SALMONN duplicate download. |
| 081 | HTML | Supporting | SALMONN model page; provider context only. |
| 082 | PDF; duplicate of 065 | Peripheral | video-SALMONN duplicate download. |

## Curated production archive and standalone paper

`Audio_Production_Papers_and_Standards.zip` contains 15 PDFs and one README. All 16 members match the extracted tree byte-for-byte. The 15 PDFs are the Core sources listed under “Core production, DSP, analysis, and standards” in `CORPUS_REVIEW.md`: compressor design and automation, intelligent multitrack compression and production strategy, differentiable effect style transfer and mixing, ST-ITO, automatic EQ, Essentia, YIN, perceptual quality, SRMR, BS.1770-5, EBU R 128, and BS.1534-3.

The separately supplied `WIMP2017_Martinez-RamirezReiss.pdf` is also Core and recovers the work referenced by TTA slots 023 and 074. It is not a member of the 10 ZIP archives.

## Remaining research-depth work

Archive extraction and indexing are complete, but deep research review is not. The next research milestone should promote the 33 Supporting PDFs in risk order (source-aware analysis, constrained EQ, program-dependent compression, evaluation, then model-provider papers) and only then decide whether any of the eight Peripheral PDFs justify full review. The missing slot 075 requires a legally obtained payload before any content claim can be made.
