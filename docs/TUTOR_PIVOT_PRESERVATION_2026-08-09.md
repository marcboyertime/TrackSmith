# LLM-first Tutor pivot preservation record

Status date: 2026-08-09

The untouched pre-pivot source was a clean worktree at exact commit:

`6843210cee66cbdbe6ada41bfaa62378ed232057`

It was preserved before implementation with:

- archival branch `archive/pre-tutor-pivot-2026-08-09`;
- annotated tag `tracksmith-pre-tutor-pivot-2026-08-09` (tag object
  `3939cd1996886737ce21126fe14928448a9b5401`);
- new implementation branch `codex/llm-first-tutor-2026-08-09` created directly
  from the untouched commit.

The new branch does not reuse the historical `codex/logic-production-tutor-v1`
branch. No history was rewritten and no force operation was used.

The product and bundle compatibility identifiers remain unchanged:

- application product/display compatibility name: `Logic Audio Assistant`;
- app bundle ID: `com.marcboyer.logicaudioassistant`;
- AU bundle ID: `com.marcboyer.logicaudioassistant.AudioUnit`;
- AU component: `aufx / LgAA / ExAI`;
- App Group: `KDV9RC892F.com.marcboyer.logicaudioassistant`.

TrackSmith is the product name in product copy and documentation. Classic Guide,
Create For Me, and Vocal remain compiled behind Future / Legacy. Their existing
files and user-controlled authority paths were not deleted or renamed, and Tutor's
tool layer does not import or expose those mutation APIs.
