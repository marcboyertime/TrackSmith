# TrackSmith Import Plan

## Storage

Stage the package under:

`research/community_knowledge/packages/tracksmith-corpus-007-phase-polarity-stereo-imaging-panning/`

Register it in the existing package registry. Large data stays in the package SQLite/JSONL layer and outside generated Swift knowledge.

## Retrieval

Extend the existing read-only community/practitioner retrieval tool or unified retrieval service. Support filters for:

- domain and subdomain;
- source/channel type;
- mono versus stereo;
- related versus unrelated signals;
- Logic version;
- microphone/DI/parallel-routing context;
- stereo source versus mono source;
- speakers versus headphones;
- technical correction versus creative spatial choice.

Return at most a compact set of:

- relevant candidate patterns;
- one material disagreement when applicable;
- a myth/anti-pattern warning when applicable;
- source/evidence classes;
- version scope;
- one suggested discriminating experiment.

## Evidence

Use a Package 007 evidence receipt containing package version, query hash, selected record IDs, source IDs/domains, result hash, and review states. Do not persist full source text in Tutor history.

## Safety and authority

Community/practitioner retrieval remains read-only. It cannot call Logic, change TrackSmith, open arbitrary files, browse the web, or execute shell commands. Exact procedures remain candidate-only until installed-version verification.
