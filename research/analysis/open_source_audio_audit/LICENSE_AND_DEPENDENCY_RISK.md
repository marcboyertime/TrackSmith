# License and dependency risk

This is a conservative engineering diligence summary, not legal advice. It reports pinned-tree evidence from the [shards](README.md) only. “None found” never means clearance. Every candidate requires a third-party manifest, exact pin/hash, notice decision, resolved dependency/SBOM review, content provenance decision, and counsel/rights-owner decision where noted before code reuse or shipping.

| # | repository | top-level / submodule risk | material dependency closure | model/data and content rights | patent/usage / required decision |
|---:|---|---|---|---|---|
| 1 | AudioKit | MIT; no submodules | no external SwiftPM packages, Apple terms outside scope | test media provenance incomplete | retain MIT notice; select exact copied scope or independently author |
| 2 | basic-pitch | Apache-2.0; no submodules | Python/ML runtime not locked to a reviewed closure | weights/data unlicensed separately; Vocadito CC-BY test audio | Apache NOTICE/patent conditions; written weights/data decision |
| 3 | NeuralNote | Apache-2.0; JUCE/Basic Pitch components | CMake/JUCE and model-runtime closure unresolved | embedded/downstream model rights unresolved | Apache notices; JUCE/model/data written clearance |
| 4 | RNNoise | BSD-style; no submodules reported | native/model build closure unresolved | model/training-data rights unresolved | BSD notice, rights determination and patent review |
| 5 | noise-suppression-for-voice | GPL-3.0 | JUCE/RNNoise/model closure does not permit closed source | plugin/model assets not cleared | GPL blocks current posture; obtain different grant or reject |
| 6 | DDSP | Apache-2.0 | TensorFlow/Python/data tooling closure unresolved | checkpoints/training sets not cleared | Apache NOTICE; separately clear every model/data use |
| 7 | webMUSHRA | custom; vendored components | Node/vendor closure unreviewed | demo WAV rights unresolved | source-delivery, naming, patent terms; written commercial rights |
| 8 | akouste | AGPL-3.0 | Node/CDN/minified provenance unresolved | fixtures/remote examples not cleared | AGPL network/source obligations; reject for closed product |
| 9 | pluginval | GPL-3.0 | JUCE and optional tools unresolved | no model; test material still not product content | GPL blocks dependency/distribution; external observation only |
| 10 | chowdsp_utils | mixed modules; tests/examples GPL | include/module closure must be selected | no model; examples are GPL expression | choose one permissive module, reject GPL paths, retain notices |
| 11 | JUCE | AGPL or commercial EULA | many SDK/codecs and optional formats | example media not product training/shipping grant | commercial agreement plus selected-SDK review; no migration approval |
| 12 | iPlug2 | zlib-style; bundled third parties | framework/module closure requires selection | no cleared product media | retain zlib/third-party notices; no framework import |
| 13 | Essentia | AGPL; submodules present | native/Python/transitive closure unresolved | models/data/content require separate checks | AGPL blocks embedding; written rights or research isolation |
| 14 | librosa | ISC | NumPy/SciPy/Numba/audio stack needs closure | downloadable examples are not TrackSmith content | ISC notice plus locked offline-tool manifest |
| 15 | madmom | BSD-like code; model gitlink | Python/Cython/ffmpeg closure unresolved | model/data CC BY-NC-SA; test media un-cleared | NC/SA/contact terms block commercial model/data use |
| 16 | Demucs | MIT; remote weights not submodule | PyTorch/audio/codecs unclosed | remote weights/training corpus and test.mp3 un-cleared | MIT notice insufficient; explicit model/data/dependency rights |

## Repository-specific commercial posture

The six columns below deliberately separate distinct questions. “No” means not approved by this audit; “conditional” means a fresh written decision and the listed gates are required. Algorithmic inspiration still requires clean-room authorship, documented sources, and patent/copyright review.

| repository | code reuse | algorithmic inspiration | pretrained model reuse | model retraining | research-only evaluation | commercial shipping |
|---|---|---|---|---|---|---|
| AudioKit | conditional MIT notice/scope | conditional | n/a | n/a | conditional, exclude fixtures | conditional narrow utility only |
| basic-pitch | conditional Apache notices, architecture unsuitable | conditional | no, weights un-cleared | no, datasets un-cleared | conditional local | no embedded runtime/model |
| NeuralNote | no current architecture path | conditional | no | no | conditional | no |
| RNNoise | conditional code only | conditional | no, model rights unresolved | no, training rights unresolved | conditional | no |
| noise-suppression-for-voice | no, GPL | conditional observation only | no | no | isolated only | no |
| DDSP | conditional code only | conditional | no | no | conditional | no |
| webMUSHRA | no closed-source reuse | conditional protocol only | n/a | n/a | conditional unmodified study | no |
| akouste | no, AGPL | conditional protocol only | n/a | n/a | conditional unmodified local | no |
| pluginval | no, GPL | conditional test ideas only | n/a | n/a | external only | no |
| chowdsp_utils | conditional selected permissive module only | conditional | n/a | n/a | conditional segregated | conditional independent native utility only |
| JUCE | no without commercial license | conditional | n/a | n/a | conditional isolated | no current approval |
| iPlug2 | conditional notice/scope | conditional | n/a | n/a | conditional | conditional independent utility only |
| Essentia | no, AGPL | conditional | no, un-cleared | no, un-cleared | isolated only | no |
| librosa | conditional offline-tool notices | conditional | n/a | n/a | conditional offline | no runtime embedding |
| madmom | code-only conditional; exclude data/models | conditional | no, NC/SA | no, NC/SA/unclear | noncommercial isolated only | no |
| Demucs | conditional MIT source only, architecture unsuitable | conditional research | no, weights un-cleared | no, corpus/derived rights un-cleared | conditional isolated local | no |

## Notes and required licensing decisions

- **AudioKit:** MIT covers source expression, not fixture provenance or Apple terms; decide per-file reuse and preserve notice.
- **basic-pitch:** Apache code does not license distributed serializations or training data. Decide weights, each dataset, runtime versions, Vocadito attribution, and all notices separately.
- **NeuralNote:** Apache source cannot clear its JUCE or Basic Pitch-derived/model/runtime surface. Obtain separate framework, weight, and data decisions before any experiment beyond documentation.
- **RNNoise:** BSD-style source notice is necessary but not sufficient for its neural model/training lineage. Clear model and data before a product proposal.
- **noise-suppression-for-voice:** GPL applies to the selected project; do not link, distribute, or copy. A future commercial grant must cover all included layers.
- **DDSP:** Apache code, TensorFlow dependencies, downloaded checkpoints, and training datasets are separate license decisions.
- **webMUSHRA:** Its custom source-delivery, modified-name, patent, and asset obligations are not compatible with current product reuse absent written rights.
- **akouste:** AGPL interactive-network obligations and unclear bundled/remote stimuli require isolation; URLs are not content licenses.
- **pluginval:** GPL and JUCE inheritance permit only external, disposable observation under an independently authored TrackSmith test plan.
- **chowdsp_utils:** The project is not uniformly permissive. Map the selected module's include tree, third-party licenses, and exclude GPL modules/examples before considering any independent implementation.
- **JUCE:** A commercial JUCE license would not itself clear SDKs, media, or authorize architecture migration. Select exact modules/formats and obtain a new product decision.
- **iPlug2:** The zlib-style top license is only a starting point; resolve selected framework components and notices, and preserve native architecture.
- **Essentia:** AGPL and its submodules prevent closed-source embedding; model/data rights and dependency closure remain separate even for research.
- **librosa:** ISC source does not clear scientific Python/audio dependencies or downloaded examples. Freeze environment and use TrackSmith-owned fixtures.
- **madmom:** CC BY-NC-SA model/data and the submodule preclude commercial model/derived-technology use without written rights.
- **Demucs:** MIT source does not license remote weights, MUSDB/extra-corpus training data, codecs, or `test.mp3`; do not download/distribute them under this audit.
