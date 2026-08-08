# TrackSmith open-source audio audit: repositories 07–11

Audit date: 2026-08-08. Links below are pinned GitHub source/commit URLs inspected from shallow local checkouts; conclusions are licensing and architecture diligence, not legal advice or production-readiness claims. “No complete closure” means the inspected tree did not itself supply a reviewed, resolved license inventory sufficient to clear a TrackSmith distribution.

## 07. webMUSHRA

### Repository URL

<https://github.com/audiolabs/webMUSHRA>

### Pinned commit or release, pin date, and inspected evidence paths

Commit [`8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5`](https://github.com/audiolabs/webMUSHRA/commit/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5), committed 2026-05-20 and inspected 2026-08-08. Evidence: [`LICENSE.txt`](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/LICENSE.txt), [`package.json`](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/package.json), [`THIRD-PARTY-NOTICES.txt`](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/THIRD-PARTY-NOTICES.txt), [`README.md`](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/README.md), [`doc/experimenter.md`](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/doc/experimenter.md), and [`service/write.php`](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/service/write.php).

### Primary language and build system

JavaScript/HTML/CSS with a PHP result endpoint; the Node manifest names Grunt test/build tooling, while deployment documentation uses a PHP server, Apache/PHP, or Docker. [package](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/package.json) [deployment docs](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/README.md#L48-L71)

### Top-level license

Custom Fraunhofer webMUSHRA Software License, not an SPDX permissive license: it requires source availability to binary recipients, prohibits charging copyright license fees, reserves patent rights, and imposes modified-version naming/notice conditions. [license](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/LICENSE.txt)

### Submodule licenses

No Git submodules were present at the inspected commit; vendored `lib/external` components instead have their own license files and notices. [third-party notice](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/THIRD-PARTY-NOTICES.txt) [commit tree](https://github.com/audiolabs/webMUSHRA/tree/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5)

### Direct and materially relevant dependency licenses; state whether a complete resolved transitive license closure exists

Manifest inventory: Grunt and seven Grunt/JSDoc development packages are range-pinned in `package.json`; the bundled notice identifies jQuery/jQuery Mobile (MIT), Mousetrap (Apache-2.0), yaml.js (MIT), and three.js (MIT). The notice expressly says external/node modules have their own terms. A complete resolved transitive license closure is **not** present in the inspected tree; `package-lock.json` is present but is not a reviewed third-party attribution/clearance report. [manifest](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/package.json) [notices](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/THIRD-PARTY-NOTICES.txt)

### Model/checkpoint/data licenses

No model, checkpoint, or ML-training-data manifest was found in the inspected source tree; this is browser listening-test software, not an inference repository. [project description](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/README.md#L11-L15)

### Bundled audio/sample/content rights

The tree includes four `configs/resources/audio/mono_*.wav` demo fixtures referenced by the example configuration, but no separate audio-rights license or provenance manifest was found; do not redistribute them with TrackSmith. [audio directory](https://github.com/audiolabs/webMUSHRA/tree/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/configs/resources/audio) [example configuration](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/configs/default.yaml)

### Documented patent or usage restrictions

The top-level license says patent licenses may be required and grants no express or implied patent license; it also forbids use of the Fraunhofer name for endorsement without permission. [license sections 1–3](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/LICENSE.txt)

### Commercial closed-source permissibility assessment, explicitly separating code reuse, algorithmic inspiration, pretrained model reuse, model retraining, research-only evaluation, and commercial shipping

**Code reuse:** not permissible for TrackSmith closed-source shipping under the supplied license without separate rights, because binary redistribution requires free source delivery and modifications carry additional conditions. **Algorithmic inspiration:** a separately authored, independently verified listening-study design may be studied; this is not permission to copy expression, assets, or patent-encumbered implementation. **Pretrained model reuse:** not applicable—none is supplied. **Model retraining:** not applicable—no model/data license is supplied. **Research-only evaluation:** permissible only as an unmodified/appropriately licensed study tool after test-method, patent, participant-data, and third-party-asset review. **Commercial shipping:** do not ship or embed absent written rights and a full dependency/content clearance. [license](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/LICENSE.txt) [test scope](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/README.md#L11-L15)

### Attribution/notices required

Any permitted redistribution must retain the complete webMUSHRA license and applicable third-party notices; modified versions must announce change/date and use the specified replacement name. [license conditions](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/LICENSE.txt) [third-party notices](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/THIRD-PARTY-NOTICES.txt)

### Maintenance status with dated evidence

Active enough to have a 2026-05-20 merge commit at the pinned head; this is dated repository activity, not a support/security guarantee. [pinned commit](https://github.com/audiolabs/webMUSHRA/commit/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5)

### Apple Silicon/macOS compatibility

Browser delivery is documented for Chrome on Mac, but no native Apple Silicon application or AU target exists; server instructions target PHP/Docker. [browser list](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/README.md#L43-L71)

### Swift/C/C++/Python interoperability

No native Swift/C/C++ API is exposed. A separate Python backend is merely linked from documentation, not included or cleared by this repository. [backend note](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/README.md#L67-L72)

### Expected binary size (evidence-backed where available; otherwise bounded estimate clearly labeled)

No native binary is produced. Evidence-backed local checkout measurement was 25,888 KiB including Git metadata; deployment size is the static web files plus selected stimuli and server/container, so no defensible AU binary estimate exists. [Dockerfile](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/Dockerfile) [audio fixtures](https://github.com/audiolabs/webMUSHRA/tree/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/configs/resources/audio)

### Expected CPU/memory use, latency, sample-rate/frame assumptions

It uses browser Web Audio and documents selectable processing buffers of 256–16,384 frames, explicitly trading smaller buffers for lower latency and higher computational load; no universal sample rate, CPU, or memory bound is documented. [experimenter configuration](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/doc/experimenter.md#L18-L23)

### Allocation and thread-safety behavior

No AU-style allocation/thread-safety contract is supplied. Browser JavaScript, DOM/UI, Web Audio, YAML/config loading, and PHP file output are outside deterministic audio-callback guarantees. [client-side scope](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/README.md#L36-L41) [write endpoint](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/service/write.php)

### Render-thread appropriateness

Not appropriate: it is a browser study application rather than bounded native DSP and must never enter the AU render callback. [project description](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/README.md#L11-L15)

### Network requirement and local handling of user audio

A web server is required to load audio and save CSV results in the documented setup; result submission can target a configured remote service or bundled PHP writer. User-provided stimulus rights, storage, and network handling remain the deploying study owner’s responsibility. [setup](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/README.md#L48-L61) [remote service field](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/doc/experimenter.md#L18-L24)

### Deterministic replay suitability

Partial at best: YAML can preserve a test definition, but browser/device timing and randomized conditions require TrackSmith to record fixture hashes, browser/environment identity, randomization seed/order, and response export hashes to replay a study. The repository documents randomized stimuli but no deterministic seed contract. [stimulus/randomization fields](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/doc/experimenter.md#L66-L77)

### Classification

LICENSE_BLOCKED

### Smallest useful TrackSmith capability

Research-only reference for an independently implemented, blinded MUSHRA/ABX/paired-comparison/ranking/likert study protocol—not code, a server, or an audio engine. [feature list](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/README.md#L28-L41)

### Proposed boundary: AU render thread; AU off-render worker; companion process; offline CLI; research-only directory; external test dependency

research-only directory

### Key unresolved diligence items

Obtain written commercial/source-distribution and patent guidance; independently inventory all Node/vendored licenses; identify/demo-audio rights; and design participant consent, retention, local/remote result handling, and browser reproducibility before even unmodified study use. [license](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/LICENSE.txt) [notices](https://github.com/audiolabs/webMUSHRA/blob/8c353f738aa88fa9dee0dc1aa7d18d2a06441cb5/THIRD-PARTY-NOTICES.txt)

### TrackSmith safeguards/tests required

Use independently authored study assets only; retain original source audio/MIDI and SHA-256 identities; persist typed intent, study configuration, seed/order, environment, consent, results, and provenance; blind identity until judgment; validate save/reload and deterministic replay; test source preservation, stale-result/rollback, notices, and the third-party manifest. Any later native evaluator must separately prove offline/realtime parity, render allocation/sanitizer cleanliness, and bounded parameter validation.

## 08. akouste

### Repository URL

<https://github.com/robvanson/akouste>

### Pinned commit or release, pin date, and inspected evidence paths

Commit [`ef5130b52c1bdec3ddf7467d50bb7f787cab27fa`](https://github.com/robvanson/akouste/commit/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa), committed 2026-07-21 and inspected 2026-08-08. Evidence: [`LICENSE.md`](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/LICENSE.md), [`README.md`](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md), [`package-lock.json`](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/package-lock.json), [`akousteHTMLtemplate.js`](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/akousteHTMLtemplate.js), and [`Examples/Examples_Readme.md`](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/Examples/Examples_Readme.md).

### Primary language and build system

Plain HTML/CSS/JavaScript client-side web application; its npm lockfile is a dependency inventory, not a native build or AU project. [README](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L15-L35) [lockfile](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/package-lock.json)

### Top-level license

GNU Affero General Public License v3. [license](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/LICENSE.md)

### Submodule licenses

No Git submodules were present at the inspected commit. [commit tree](https://github.com/robvanson/akouste/tree/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa)

### Direct and materially relevant dependency licenses; state whether a complete resolved transitive license closure exists

Direct dependencies are jsSHA, markdown-it, marked, and Remarkable; `package-lock.json` resolves registry versions and records package license fields (for example jsSHA BSD-3-Clause and markdown-it MIT) while the README says only local `markdown-it.min.js` and `sha.js` are bundled. A resolved Node version inventory exists, but a complete independently reviewed license closure does **not**: optional CDN loads and bundled/minified-copy provenance still require review. [lockfile](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/package-lock.json) [dependency explanation](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L389-L429)

### Model/checkpoint/data licenses

No model or checkpoint is supplied. The repository includes test stimuli and links to remote Wikimedia/pseudonymization examples, none of which establishes rights for TrackSmith training or shipping. [examples](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L37-L60) [remote examples](https://github.com/robvanson/akouste/tree/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/ExpAcronym_examples)

### Bundled audio/sample/content rights

Bundled WAV/MP3/OGG fixtures are not cleared by a dedicated content license; the project says original audio for some experiments could not be shared for privacy and labels examples as placeholders, while README credits random examples to Wikimedia Commons. Exclude every fixture, downloaded example, image, and video from TrackSmith. [examples notice](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/Examples/Examples_Readme.md) [example attribution](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L37-L60)

### Documented patent or usage restrictions

No patent grant/restriction was found beyond AGPLv3’s terms. AGPL requires corresponding-source and network-interaction obligations for covered modified works; legal review must determine any combination/derivative-work boundary. [license](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/LICENSE.md)

### Commercial closed-source permissibility assessment, explicitly separating code reuse, algorithmic inspiration, pretrained model reuse, model retraining, research-only evaluation, and commercial shipping

**Code reuse:** do not use in TrackSmith’s closed-source product; AGPL is incompatible absent separate commercial permission. **Algorithmic inspiration:** study only at the abstract protocol level, with clean-room authorship and no copied expression/assets. **Pretrained model reuse:** not applicable. **Model retraining:** not applicable; bundled/linked stimuli are not a training grant. **Research-only evaluation:** running an unmodified local copy can inform internal method study, while any distribution/service/modified-work use needs AGPL compliance review. **Commercial shipping:** prohibited for the current closed-source architecture without separately obtained rights. [license](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/LICENSE.md) [local design](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L15-L20)

### Attribution/notices required

Any compliant AGPL distribution/service must meet the AGPL’s source/license and interactive-notice obligations, plus third-party package notices; TrackSmith should not attempt this route without counsel and an approved manifest. [AGPL text](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/LICENSE.md) [dependency list](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/package-lock.json)

### Maintenance status with dated evidence

The pinned head is a 2026-07-21 documentation commit; that is recent repository activity, not an assurance of platform/security support. [pinned commit](https://github.com/robvanson/akouste/commit/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa)

### Apple Silicon/macOS compatibility

Browser-local HTML is documented for desktops, mobiles, local disks, and thumb drives; no native macOS/Apple-Silicon binary or AU target is provided. [README](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L15-L35)

### Swift/C/C++/Python interoperability

None is supplied: this is generated browser HTML/JavaScript, not a native library or Python package. [self-contained page description](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L84-L100)

### Expected binary size (evidence-backed where available; otherwise bounded estimate clearly labeled)

No native binary exists. Evidence-backed local checkout measurement was 4,180 KiB including Git metadata; static experiment size is content-dependent (the supplied fixtures alone are about 2 MiB), so there is no AU binary estimate. [fixture directory](https://github.com/robvanson/akouste/tree/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/Examples) [stimulus directory](https://github.com/robvanson/akouste/tree/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/Stimuli)

### Expected CPU/memory use, latency, sample-rate/frame assumptions

No DSP CPU/memory/latency/sample-rate/frame bound is documented; the browser plays stimuli in formats supported by the selected browser. [format statement](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L23-L35)

### Allocation and thread-safety behavior

No native real-time contract exists. The template dynamically updates DOM state, stores responses/stimulus lists in `localStorage`, and randomly shuffles with `Math.random()`, all inappropriate as an AU callback contract. [state handling](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/akousteHTMLtemplate.js#L158-L170) [shuffle](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/akousteHTMLtemplate.js#L579-L607)

### Render-thread appropriateness

Not appropriate: browser UI/audio playback and local storage must remain outside TrackSmith’s AU render callback. [application scope](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L15-L20)

### Network requirement and local handling of user audio

It is designed to run locally/offline with browser-local intermediate data and subject-controlled result download; network is needed only for remote stimuli or optional library loading/checks. This is useful privacy inspiration but not a TrackSmith data-processing guarantee. [local handling](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L15-L20) [network caveat](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L84-L100)

### Deterministic replay suitability

Insufficient as-is: self-contained Markdown/CSV describes a study and chained digests can detect row corruption, but `Math.random()` has no recorded seed; TrackSmith must record deterministic order/seed and fixture hashes independently. [study description](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L98-L101) [digest](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L261-L273) [random source](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/akousteHTMLtemplate.js#L579-L607)

### Classification

LICENSE_BLOCKED

### Smallest useful TrackSmith capability

Research-only design reference for locally retained, blinded listening-evaluation export and integrity-recording requirements; independently implement any approved native evaluator. [local result workflow](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L15-L20)

### Proposed boundary: AU render thread; AU off-render worker; companion process; offline CLI; research-only directory; external test dependency

research-only directory

### Key unresolved diligence items

Obtain separate licensing only if reuse is contemplated; do not clear remote examples by URL alone; verify all local/minified package provenance; and independently specify consent, subject identifiers, retention/export policy, deterministic randomization, and a native macOS evaluator. [license](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/LICENSE.md) [dependency caveat](https://github.com/robvanson/akouste/blob/ef5130b52c1bdec3ddf7467d50bb7f787cab27fa/README.md#L389-L429)

### TrackSmith safeguards/tests required

Keep original source audio/MIDI immutable and hash-identified; store typed intent, study plan, deterministic seed/order, local-only result/provenance, and blinded identity; prove save/reload, replay, source preservation, stale-result/rollback, notice, and third-party-manifest behavior. A future native preview path must additionally prove allocation/sanitizer cleanliness and offline/realtime parity; provider output remains bounded validated parameters only.

## 09. pluginval

### Repository URL

<https://github.com/Tracktion/pluginval>

### Pinned commit or release, pin date, and inspected evidence paths

Commit [`4c5adc2c1a9910251667152166139a0c37b953e6`](https://github.com/Tracktion/pluginval/commit/4c5adc2c1a9910251667152166139a0c37b953e6), committed 2026-06-07 and inspected 2026-08-08. Evidence: [`LICENSE`](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/LICENSE), [`CMakeLists.txt`](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt), [`Source/RTCheck.h`](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/Source/RTCheck.h), [`Source/TestUtilities.cpp`](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/Source/TestUtilities.cpp), and [`Source/Validator.cpp`](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/Source/Validator.cpp).

### Primary language and build system

C++20/CMake GUI and command-line plugin-validation host based on JUCE; CMake optionally builds a VST3 validator and rtcheck integration. [CMake configuration](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L1-L85) [sources](https://github.com/Tracktion/pluginval/tree/4c5adc2c1a9910251667152166139a0c37b953e6/Source)

### Top-level license

GNU General Public License v3. [license](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/LICENSE)

### Submodule licenses

No Git submodules were present at the inspected commit; CMake obtains dependencies at configure time instead. [CMake dependency declarations](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L60-L100)

### Direct and materially relevant dependency licenses; state whether a complete resolved transitive license closure exists

Manifest inventory: magic_enum `v0.9.7`, rtcheck at mutable `main` when enabled, JUCE `8.0.13` when top-level, and Steinberg VST3 SDK `v3.7.14_build_55`; the target also enables hosts for AU/LADSPA/VST3/LV2 and embeds `vstvalidator`. No complete resolved transitive license closure exists: rtcheck is unpinned, JUCE has its own dual-license gate, and SDK/license obligations must be reviewed per selected formats. [CMake dependencies](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L60-L100) [host flags/embed](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L150-L215)

### Model/checkpoint/data licenses

No model, checkpoint, or training-data asset is supplied; validation loads external plugin binaries, whose rights and behavior are outside this repository. [validation entry point](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/Source/Validator.cpp)

### Bundled audio/sample/content rights

No bundled audio/media fixtures were found in the pinned tree. The embedded VST3 validator is a binary component, not audio content, and carries its SDK diligence requirements. [embedding step](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L188-L203)

### Documented patent or usage restrictions

GPLv3’s patent and conveying terms apply to pluginval code; optional plugin-format SDKs introduce separate terms, especially for any selected format. The audit did not find a proprietary Tracktion exception. [GPL text](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/LICENSE) [SDK declaration](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L75-L100)

### Commercial closed-source permissibility assessment, explicitly separating code reuse, algorithmic inspiration, pretrained model reuse, model retraining, research-only evaluation, and commercial shipping

**Code reuse:** do not integrate GPLv3 code/binary into closed-source TrackSmith. **Algorithmic inspiration:** independently authored test cases and high-level validation goals may be studied without copying code/fixtures. **Pretrained model reuse:** not applicable. **Model retraining:** not applicable. **Research-only evaluation:** an unmodified separately obtained tool may be run against disposable test builds if its GPL/SDK distribution terms are honored and it is never shipped inside TrackSmith. **Commercial shipping:** no embedding or bundled distribution under the present closed-source scope. [GPL](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/LICENSE) [test-host scope](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L150-L160)

### Attribution/notices required

Any GPL-compliant conveyance requires GPL/source/copyright obligations; selected JUCE, VST3 SDK, magic_enum, and rtcheck obligations must be captured from the resolved build. TrackSmith should record only a separate external-tool manifest unless licensing direction changes. [GPL](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/LICENSE) [dependency declarations](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L60-L100)

### Maintenance status with dated evidence

The pinned head was committed 2026-06-07; this supports current activity only, not compatibility with a particular plugin/host. [pinned commit](https://github.com/Tracktion/pluginval/commit/4c5adc2c1a9910251667152166139a0c37b953e6)

### Apple Silicon/macOS compatibility

Apple is a supported CMake branch with hardened runtime and rtcheck packaging; universal `arm64 x86_64` is shown only as a commented option, so Apple Silicon/universal output must be built and verified rather than assumed. [Apple CMake branch](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L5-L16) [hardened runtime](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L110-L125)

### Swift/C/C++/Python interoperability

It is C++ only; no SwiftPM, C ABI, or Python binding is supplied. Use only as a separately invoked executable in a non-shipping verification environment. [target declaration](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L100-L150)

### Expected binary size (evidence-backed where available; otherwise bounded estimate clearly labeled)

No release artifact size is recorded at the pin. **Bounded estimate, unverified:** a macOS GUI host containing JUCE plus an embedded VST3 validator should be treated as a 10–100 MiB external test-tool class until a reproducible universal build is measured; source CMake explicitly embeds the validator binary. [embed mechanism](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L188-L203)

### Expected CPU/memory use, latency, sample-rate/frame assumptions

There is no fixed budget: pluginval loads arbitrary third-party plugins and runs validation, so CPU, memory, audio configuration, latency, crashes, and hangs depend materially on the candidate. It includes timeout handling that may sleep then terminate the process, confirming it is test-host rather than render DSP. [timeout thread](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/Source/Validator.cpp#L20-L100)

### Allocation and thread-safety behavior

It deliberately intercepts global allocations for tests and has optional rtcheck contexts, but also uses threads, file output, timers/sleeps, process termination, and arbitrary plugin code. This is useful validation instrumentation, not a guarantee that TrackSmith render code is allocation-free or thread-safe. [allocation tests](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/Source/TestUtilities.cpp#L69-L243) [rtcheck](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/Source/RTCheck.h) [timeout](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/Source/Validator.cpp#L20-L100)

### Render-thread appropriateness

Not appropriate: run as a bounded external validation process only, never in AU render or as a companion that receives live audio. [GUI-app target](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L105-L125) [validator behavior](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/Source/Validator.cpp#L20-L100)

### Network requirement and local handling of user audio

Runtime network is intentionally disabled for its JUCE target (`JUCE_USE_CURL=0`, web browser off), but CMake fetches dependencies during build and validation executes local plugin binaries. Do not expose user projects/audio to it; use synthetic, hash-audited fixtures. [network flags](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L150-L165) [CMake fetches](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L60-L100)

### Deterministic replay suitability

Suitable only as an external regression signal when the exact tool commit, resolved dependency/SDK versions, host/OS/architecture, command line, plugin artifact hash, test fixtures, logs, and timeout are archived. The mutable rtcheck `main` reference otherwise prevents reproducible dependency resolution. [mutable dependency](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L60-L72) [CLI source](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/Source/CommandLine.cpp)

### Classification

LICENSE_BLOCKED

### Smallest useful TrackSmith capability

External, non-shipping regression gate for a disposable AU build: capture a pass/fail/log artifact and use its allocation/format-hostility test *ideas* to author independent tests. [test source inventory](https://github.com/Tracktion/pluginval/tree/4c5adc2c1a9910251667152166139a0c37b953e6/Source/tests)

### Proposed boundary: AU render thread; AU off-render worker; companion process; offline CLI; research-only directory; external test dependency

external test dependency

### Key unresolved diligence items

Confirm GPL policy for internal CI acquisition, pin/fork or otherwise lock rtcheck, resolve and inventory every CMake download/SDK license, build/verify arm64 or universal output, and establish isolated crash-safe test machines with no customer audio/project data. [dependency list](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L60-L100) [Apple branch](https://github.com/Tracktion/pluginval/blob/4c5adc2c1a9910251667152166139a0c37b953e6/CMakeLists.txt#L5-L16)

### TrackSmith safeguards/tests required

Use only generated/hash-audited fixtures and disposable hosts; archive exact commands, tool/dependency/plugin hashes, architecture, logs, crash/timeout results, and notice manifest. Independently test deterministic replay, save/reload, source preservation, rollback/stale-result behavior, allocation/sanitizers, and offline/realtime parity in TrackSmith; never let a provider, pluginval, or an external plugin select arbitrary DSP/code.

## 10. chowdsp_utils

### Repository URL

<https://github.com/Chowdhury-DSP/chowdsp_utils>

### Pinned commit or release, pin date, and inspected evidence paths

Commit [`e97b826ef3de0b0fd92b15cb2e286076f678d8b9`](https://github.com/Chowdhury-DSP/chowdsp_utils/commit/e97b826ef3de0b0fd92b15cb2e286076f678d8b9), committed 2025-12-09 and inspected 2026-08-08. Evidence: [`LICENSE.md`](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/LICENSE.md), [`CMakeLists.txt`](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/CMakeLists.txt), [module headers](https://github.com/Chowdhury-DSP/chowdsp_utils/tree/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules), and [`EQProcessor`](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_eq/EQ/chowdsp_EQProcessor.cpp).

### Primary language and build system

C++17 CMake project organized as JUCE modules; normal configuration either installs/exports modules or adds them through JUCE-module helpers, while tests/benchmarks/examples are optional. [CMake](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/CMakeLists.txt)

### Top-level license

There is no single permissive project license: `LICENSE.md` says every module has its own license and all non-module tests/examples/benchmarks are GPLv3. [license policy](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/LICENSE.md)

### Submodule licenses

No Git submodules were present at the inspected commit. Vendored third-party directories are ordinary tree content, not submodules. [commit tree](https://github.com/Chowdhury-DSP/chowdsp_utils/tree/e97b826ef3de0b0fd92b15cb2e286076f678d8b9) [third-party example](https://github.com/Chowdhury-DSP/chowdsp_utils/tree/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_simd/third_party)

### Direct and materially relevant dependency licenses; state whether a complete resolved transitive license closure exists

Module headers declare mixed BSD-3-Clause and GPLv3 terms: BSD examples include `chowdsp_core`, `data_structures`, `buffers`, `math`, `simd`, and `rhythm`; DSP modules such as filters, compressor, EQ, reverb, sources, and waveshapers are GPLv3. Vendored inventory includes span-lite/Boost-1.0, types_list/MIT, spdlog/MIT, magic_enum/MIT, pfr/Boost-1.0, moodycamel/BSD or Boost, gcem/Apache-2.0, and xsimd/BSD-3-Clause; some modules depend on JUCE and `chowdsp_dsp_utils` can opt into libsamplerate. A complete resolved transitive license closure is **not** available because module selection, JUCE mode/license, optional libsamplerate, and other external build choices are unresolved. [module declarations](https://github.com/Chowdhury-DSP/chowdsp_utils/tree/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules) [GPL DSP header](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_filters/chowdsp_filters.h) [BSD buffer header](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_buffers/chowdsp_buffers.h) [optional libsamplerate](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_dsp_utils/chowdsp_dsp_utils.h) [vendored licenses](https://github.com/Chowdhury-DSP/chowdsp_utils/tree/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules)

### Model/checkpoint/data licenses

No model, checkpoint, or ML-training-data manifest is supplied. [repository tree](https://github.com/Chowdhury-DSP/chowdsp_utils/tree/e97b826ef3de0b0fd92b15cb2e286076f678d8b9)

### Bundled audio/sample/content rights

No audio/media files were found in the inspected pinned tree; examples are GPLv3 code and must not be treated as content or code cleared for closed-source reuse. [license policy](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/LICENSE.md) [examples](https://github.com/Chowdhury-DSP/chowdsp_utils/tree/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/examples)

### Documented patent or usage restrictions

The project directs proprietary users of GPL-style modules to contact the author for non-GPL licensing; no patent grant or blanket commercial exception was found. [license policy](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/LICENSE.md)

### Commercial closed-source permissibility assessment, explicitly separating code reuse, algorithmic inspiration, pretrained model reuse, model retraining, research-only evaluation, and commercial shipping

**Code reuse:** only a specifically selected BSD/permissive module and all of its reviewed dependencies could be considered; do not reuse any GPL module, example, benchmark, or test in TrackSmith without a separate commercial license. **Algorithmic inspiration:** independently reimplement only after clean-room specification and numerical/latency evaluation. **Pretrained model reuse:** not applicable. **Model retraining:** not applicable. **Research-only evaluation:** permissive/GPL modules may be studied in a segregated research environment with notices retained. **Commercial shipping:** no current permission for the useful GPL DSP modules; a narrowly selected permissive module remains conditional on dependency clearance and a native reimplementation rather than importing JUCE/C++. [license policy](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/LICENSE.md) [module terms](https://github.com/Chowdhury-DSP/chowdsp_utils/tree/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules)

### Attribution/notices required

For any approved permissive reuse, preserve the selected module’s BSD notice and every included third-party notice; Apache components require their license/NOTICE handling. GPL modules require GPL compliance or separately obtained commercial rights. [module license examples](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/common/chowdsp_core/chowdsp_core.h) [gcem license](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_math/third_party/gcem/LICENSE) [project policy](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/LICENSE.md)

### Maintenance status with dated evidence

Pinned head is a 2025-12-09 commit; this is the latest observed pinned activity, not a support or compatibility promise. [pinned commit](https://github.com/Chowdhury-DSP/chowdsp_utils/commit/e97b826ef3de0b0fd92b15cb2e286076f678d8b9)

### Apple Silicon/macOS compatibility

No standalone macOS binary is supplied. The vendored SIMD tree contains NEON/NEON64 architecture support, but this is evidence of source-level ARM pathways only; Apple-Silicon compilation, numerical parity, and performance require TrackSmith-owned validation. [xsimd architecture sources](https://github.com/Chowdhury-DSP/chowdsp_utils/tree/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_simd/third_party/xsimd/include/xsimd/arch)

### Swift/C/C++/Python interoperability

C++/JUCE modules only; no SwiftPM package, stable C ABI, or Python binding is supplied. Any eventual Swift capability must be independently implemented or use a separately reviewed boundary—not a framework migration. [CMake integration modes](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/CMakeLists.txt)

### Expected binary size (evidence-backed where available; otherwise bounded estimate clearly labeled)

No executable target or release artifact is produced by the default module configuration, so binary size is not applicable until a selected module set is compiled. Evidence-backed local checkout measurement was 19,092 KiB including Git metadata; do not infer shipped size from it. [CMake targets](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/CMakeLists.txt)

### Expected CPU/memory use, latency, sample-rate/frame assumptions

No repository-wide budget exists. Individual processors accept a JUCE `ProcessSpec` (sample rate, max block, channels); for example EQ prepares smoothers with the supplied sample rate/maximum block and defaults a linear-phase wrapper to 48 kHz/512 frames, while its latency is explicitly queryable. Treat CPU/memory/latency as processor-specific and measure a native Swift implementation at TrackSmith’s actual formats. [EQ preparation](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_eq/EQ/chowdsp_EQBand.cpp#L38-L62) [linear-phase assumptions](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_eq/EQ/chowdsp_LinearPhaseEQ.h#L64-L98)

### Allocation and thread-safety behavior

There is no whole-repository real-time guarantee. Some EQ paths preallocate/reset an internal arena and expose `noexcept processBlock`, but other modules include queues, futures, GUI, logging, or state helpers; each selected component needs separate allocation/locking analysis. [EQ arena/process](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_eq/EQ/chowdsp_EQProcessor.cpp#L56-L94) [waveshaper future include](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_waveshapers/chowdsp_waveshapers.h)

### Render-thread appropriateness

Only a newly authored, fixed-capacity native translation of a specifically cleared bounded algorithm could be considered for the AU render thread after proof; the repository as a whole is not render-thread eligible due to licensing, JUCE coupling, and mixed module behavior. [module dependency example](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_filters/chowdsp_filters.h) [project license policy](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/LICENSE.md)

### Network requirement and local handling of user audio

No runtime network behavior is inherent in the DSP modules; CMake/test tooling and optional dependencies are build-time concerns. Any TrackSmith reimplementation must keep user audio local and original media immutable. [CMake](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/CMakeLists.txt)

### Deterministic replay suitability

Potentially suitable only for a TrackSmith-owned fixed-parameter translation: persist versioned typed parameters, sample rate, frame size, channels, state/reset event, source hash, and output hash. The repository’s configurable, module-level processing API is not itself a replay record or guarantee. [process specification use](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_eq/EQ/chowdsp_EQBand.cpp#L38-L62)

### Classification

SAFE_TO_PORT_SELECTIVELY

### Smallest useful TrackSmith capability

Use the BSD module declarations and preallocation-oriented buffer/EQ patterns as a research specification for one independently authored, fixed-capacity utility—not a source import and not any GPL dynamics/EQ/reverb/waveshaper module. [BSD buffers](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_buffers/chowdsp_buffers.h) [GPL EQ](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules/dsp/chowdsp_eq/chowdsp_eq.h)

### Proposed boundary: AU render thread; AU off-render worker; companion process; offline CLI; research-only directory; external test dependency

AU render thread

### Key unresolved diligence items

Select exactly one candidate module/algorithm; map its complete include/dependency closure and all notices; obtain rights for anything GPL; prove that a native Swift translation has no JUCE dependence, heap allocation, lock, I/O, network, nondeterminism, or unbounded state; and measure arm64/x86_64 numerical/CPU/latency parity. [module terms](https://github.com/Chowdhury-DSP/chowdsp_utils/tree/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/modules) [license policy](https://github.com/Chowdhury-DSP/chowdsp_utils/blob/e97b826ef3de0b0fd92b15cb2e286076f678d8b9/LICENSE.md)

### TrackSmith safeguards/tests required

Before implementation, write an independent bounded specification and third-party manifest. Require deterministic replay, save/reload, offline/realtime parity, allocation and sanitizer tests, source-preservation hashes, rollback/stale-result rejection, notice verification, latency/tail and sample-rate/block/channel matrices, plus stable parameter validation. Provider proposals may select only values inside that predeclared typed parameter schema.

## 11. JUCE

### Repository URL

<https://github.com/juce-framework/JUCE>

### Pinned commit or release, pin date, and inspected evidence paths

Commit [`7dda739b9be09f1dfb9592a09e1701acf808cd44`](https://github.com/juce-framework/JUCE/commit/7dda739b9be09f1dfb9592a09e1701acf808cd44), committed 2026-07-30 and inspected 2026-08-08. Evidence: [`LICENSE.md`](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/LICENSE.md), [`README.md`](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/README.md), [`CMakeLists.txt`](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/CMakeLists.txt), and [`AudioProcessor`](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/modules/juce_audio_processors_headless/processors/juce_AudioProcessor.h).

### Primary language and build system

C/C++17 cross-platform application/audio-plugin framework using CMake 3.22+ (or Projucer); it covers AU/AUv3 and other plugin formats. [README](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/README.md#L3-L8) [CMake](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/CMakeLists.txt#L35-L90)

### Top-level license

Modules are dual-licensed AGPLv3 or the JUCE commercial license/EULA; no TrackSmith commercial JUCE license was supplied for this audit. [license](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/LICENSE.md)

### Submodule licenses

No Git submodules were present at the inspected commit. JUCE instead vendors numerous SDKs/codecs/libraries in its module tree. [commit tree](https://github.com/juce-framework/JUCE/tree/7dda739b9be09f1dfb9592a09e1701acf808cd44) [dependency inventory](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/LICENSE.md)

### Direct and materially relevant dependency licenses; state whether a complete resolved transitive license closure exists

JUCE’s own inventory names AudioUnitSDK/Apache-2.0, Oboe/Apache-2.0, FLAC and Ogg Vorbis/BSD, jpeglib/IJG, CHOC/ISC plus QuickJS/MIT, LV2/ISC, VST3/MIT, AAX proprietary-or-GPLv3, ASIO proprietary-or-GPLv3, zlib, HarfBuzz, SheenBidi/Apache, LunaSVG/PlutoVG MIT, and OpenGL-header notices; it separately labels examples ISC. This is a valuable manifest inventory but not a complete cleared TrackSmith closure because selected JUCE modules, optional SDKs, AAX/ASIO paths, generated build tools, and the governing commercial EULA must be resolved for the actual distribution. [license inventory](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/LICENSE.md)

### Model/checkpoint/data licenses

No model/checkpoint/training-data package is supplied. [repository scope](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/README.md#L3-L8)

### Bundled audio/sample/content rights

Examples/assets include audio, impulse-response, notification, and purchase-demo files, while JUCE says examples are ISC but does not provide a TrackSmith-specific content provenance/training license for those individual media files. Exclude all example media from TrackSmith shipping/training unless separately traced and cleared. [example assets](https://github.com/juce-framework/JUCE/tree/7dda739b9be09f1dfb9592a09e1701acf808cd44/examples/Assets) [example license statement](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/LICENSE.md)

### Documented patent or usage restrictions

Use is governed by AGPLv3 or the current commercial JUCE EULA, which incorporates privacy and website terms; bundled AAX and ASIO have proprietary-or-GPL terms, and AAX commercial operation requires PACE signing according to the README. [JUCE terms](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/LICENSE.md) [AAX note](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/README.md#L87-L90)

### Commercial closed-source permissibility assessment, explicitly separating code reuse, algorithmic inspiration, pretrained model reuse, model retraining, research-only evaluation, and commercial shipping

**Code reuse:** closed-source reuse is not cleared under AGPL; it is conditionally possible only after TrackSmith obtains and complies with a suitable current JUCE commercial license and selected SDK terms. **Algorithmic inspiration:** architecture/test ideas may be studied without copying expression or importing the framework. **Pretrained model reuse:** not applicable. **Model retraining:** not applicable; example media is not a training grant. **Research-only evaluation:** an isolated checkout may inform compatibility research, retaining licenses/notices and excluding TrackSmith content. **Commercial shipping:** do not embed, migrate, or ship JUCE under the present evidence; a future commercial agreement would still not authorize framework migration without separate product approval. [license](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/LICENSE.md) [framework scope](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/README.md#L3-L8)

### Attribution/notices required

AGPL use requires AGPL compliance; commercial use follows the applicable EULA. In either case preserve applicable third-party notices for selected components, especially format SDKs/codecs. [license and inventory](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/LICENSE.md)

### Maintenance status with dated evidence

The pinned head is a 2026-07-30 CI change and declares JUCE 9.0.0 in CMake; this is recent maintenance evidence, not a support commitment to TrackSmith. [pinned commit](https://github.com/juce-framework/JUCE/commit/7dda739b9be09f1dfb9592a09e1701acf808cd44) [version declaration](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/CMakeLists.txt#L35-L40)

### Apple Silicon/macOS compatibility

JUCE documents macOS/iOS support with Apple Silicon macOS 11.0/Xcode 12.4 minimum and macOS deployment for x86_64/Arm64. This establishes framework support, not TrackSmith host/plugin validation. [requirements](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/README.md#L60-L75)

### Swift/C/C++/Python interoperability

JUCE is C/C++ and CMake/Projucer oriented; no SwiftPM package or Python API is supplied. TrackSmith must retain native SwiftPM/macOS/AUv3 architecture rather than wrap/migrate to JUCE. [build docs](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/README.md#L21-L48)

### Expected binary size (evidence-backed where available; otherwise bounded estimate clearly labeled)

JUCE is a source framework, not a single binary. No evidence-backed TrackSmith binary-size estimate is possible: the default CMake configuration builds helper tooling and leaves examples/extras off unless explicitly enabled, while final size depends on selected modules/formats/assets. [CMake defaults](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/CMakeLists.txt#L75-L125)

### Expected CPU/memory use, latency, sample-rate/frame assumptions

No framework-wide bound exists. `AudioProcessor` exposes host-provided channels, precision, and realtime/non-realtime state; plugin/DSP/module choice determines allocation, CPU, latency, and buffers. [audio callback contract](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/modules/juce_audio_processors_headless/processors/juce_AudioProcessor.h#L120-L130) [offline state](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/modules/juce_audio_processors_headless/processors/juce_AudioProcessor.h#L976-L996)

### Allocation and thread-safety behavior

The framework does not give a whole-framework allocation-free/thread-safe guarantee: its API warns that callbacks run on the audio thread and disallows UI interaction there, while other modules allocate, use message-thread APIs, locks, thread pools, and asynchronous scanning. Every selected path requires independent proof. [callback warning](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/modules/juce_audio_processors_headless/processors/juce_AudioProcessor.h#L205-L220) [async scanner](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/modules/juce_audio_processors/scanning/juce_PluginListComponent.cpp#L160-L240) [audio-thread allocation avoidance example](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/modules/juce_audio_plugin_client/juce_audio_plugin_client_VST3.cpp#L2580-L2587)

### Render-thread appropriateness

The abstract callback model is render-thread aware, but JUCE as a framework is not appropriate for TrackSmith’s render thread: the commercial/AGPL gate, framework migration, and mixed allocation/thread surface violate the settled native SwiftPM/AUv3 boundary. [audio callback guidance](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/modules/juce_audio_processors_headless/processors/juce_AudioProcessor.h#L205-L220) [license](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/LICENSE.md)

### Network requirement and local handling of user audio

JUCE itself is not a required network service, but it contains optional network/web/platform modules and no TrackSmith-specific local-audio/provenance policy. TrackSmith must continue local handling through its existing App Group/typed-plan boundaries and never route user audio to a model or provider from render. [framework scope](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/README.md#L3-L8)

### Deterministic replay suitability

The framework alone is insufficient: replay depends on chosen processor/modules, parameter/state serialization, host sample rate/block/precision, platform/architecture, and input hashes. JUCE’s explicit realtime/non-realtime state is a useful scenario to independently test, not a TrackSmith replay guarantee. [realtime state API](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/modules/juce_audio_processors_headless/processors/juce_AudioProcessor.h#L976-L996)

### Classification

LICENSE_BLOCKED

### Smallest useful TrackSmith capability

Research-only source of AU/AUv3 host-edge-case, state, latency/tail, and realtime/offline test scenarios to independently reproduce in the existing native stack. [AUv3 capability statement](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/README.md#L3-L8) [realtime API](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/modules/juce_audio_processors_headless/processors/juce_AudioProcessor.h#L976-L996)

### Proposed boundary: AU render thread; AU off-render worker; companion process; offline CLI; research-only directory; external test dependency

research-only directory

### Key unresolved diligence items

If JUCE use is ever proposed, obtain commercial terms and review their current version; select exact modules/formats; resolve AAX/ASIO/VST3 and all transitive obligations; measure universal binaries and host compatibility; and obtain explicit architecture approval. None of that authorizes a SwiftPM/AUv3 rewrite. [license inventory](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/LICENSE.md) [platform requirements](https://github.com/juce-framework/JUCE/blob/7dda739b9be09f1dfb9592a09e1701acf808cd44/README.md#L60-L75)

### TrackSmith safeguards/tests required

Retain the native architecture and test independently derived scenarios: deterministic replay, save/reload, host sample-rate/block/precision and offline/realtime parity, allocation/sanitizer checks, source preservation/hashes, rollback/stale-result rejection, notice/third-party-manifest validation, AU lifecycle/latency/tail/state behavior, and bounded provider parameters. Preserve original source audio/MIDI and provenance; no model or provider may choose arbitrary code, DSP, files, or AU state.
