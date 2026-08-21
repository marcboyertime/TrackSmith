P9_ARCHIVE ?= /tmp/tracksmith-package9.pwHKlg/package.zip
.PHONY: general-tutor-knowledge-audit community-corpus-check community-automation-preflight community-saturation-transient-preflight community-phase-stereo-panning-check community-editing-layering-check community-gain-bus-loudness-check community-corpus-preflight-selftest build test tutor-conversation-test tutor-audio-intelligence-lab logic-tutor-observation-probe demo demo-audio preview-demo audition vertical-slice project au-host-probe realtime-heap-probe production-language-knowledge-check tutor-procedure-knowledge-check tutor-evaluation general-tutor-knowledge-check general-tutor-knowledge-audit general-tutor-evaluation vocal-evaluation vocal-listening-selfcheck p16-golden p16-performance p16-fallback p16-evidence-audit p16-evidence-smoke p16-controlled-fixtures p16-provider-report p17-diagnostics p17-performance p17-evaluation p17-live-evaluation p17-cloud-evaluation p17-cloud-health p17-public-audio-evaluation p18-index-check p18-audit p18-diagnostics native-build native-verify native-install verify

build:
	swift build -c release

test:
	swift run -c release TestRunner

tutor-conversation-test:
	swift run -c release TutorConversationTests

p16-golden:
	swift run -c release TutorConversationTests package16-golden

p16-performance:
	swift run -c release TutorConversationTests package16-performance

p16-fallback:
	swift run -c release TutorConversationTests package16-fallback

p17-diagnostics:
	swift run -c release TutorConversationTests package17-diagnostics

p17-performance:
	swift run -c release TutorConversationTests package17-performance

p17-evaluation:
	python3 research/scripts/package17-evaluation.py --check

p17-live-evaluation:
	swift run -c release TutorConversationTests package17-live-evaluation

p17-cloud-evaluation:
	@test "$(CLOUD_TEXT_CONSENT)" = "YES" || (echo 'set CLOUD_TEXT_CONSENT=YES to send 36 P17 text requests' && exit 2)
	swift run -c release TutorConversationTests package17-cloud-evaluation --cloud-text-consent

p17-cloud-health:
	@test "$(CLOUD_TEXT_CONSENT)" = "YES" || (echo 'set CLOUD_TEXT_CONSENT=YES to send one P17 cloud health request' && exit 2)
	swift run -c release TutorConversationTests package17-cloud-health --cloud-text-consent

p17-public-audio-evaluation:
	@test "$(CLOUD_AUDIO_CONSENT)" = "YES" || (echo 'set CLOUD_AUDIO_CONSENT=YES to send one bounded P16 public WAV' && exit 2)
	swift run -c release TutorConversationTests package17-public-audio-evaluation --cloud-audio-consent

p18-index-check:
	python3 research/scripts/build_candidate_retrieval_index.py --check

p18-audit: p18-index-check
	python3 research/scripts/package18_audit.py

p18-diagnostics:
	swift run -c release TutorConversationTests package18-diagnostics

p16-evidence-audit:
	python3 research/scripts/package16-evidence-release.py --audit

p16-evidence-smoke:
	python3 research/scripts/package16-evidence-release.py --smoke

p16-controlled-fixtures:
	python3 research/scripts/package16-evidence-release.py --fixtures

p16-provider-report:
	python3 research/scripts/package16-evidence-release.py --provider-report

tutor-audio-intelligence-lab:
	swift run -c release TutorAudioIntelligenceLab --output research/evaluation/tutor-audio-intelligence-v1

logic-tutor-observation-probe:
	swift run -c release LogicTutorObservationProbe

demo:
	swift run -c release CompanionApp make this clearer and more controlled

demo-audio:
	swift run -c release TestSignalGenerator fixtures/generated/demo-vocal.wav

preview-demo: demo-audio
	swift run -c release PreviewCLI fixtures/generated/demo-vocal.wav --source vocal --prompt "make this clearer and more controlled"

audition:
	@test -n "$(SESSION)" || (echo 'usage: make audition SESSION="/path/to/preview folder"' && exit 2)
	swift run -c release AuditionApp "$(SESSION)"

vertical-slice:
	@test -n "$(INPUT)" || (echo 'usage: make vertical-slice INPUT="/path/to/audio.wav" OUTPUT="/path/to/new evidence folder"' && exit 2)
	@test -n "$(OUTPUT)" || (echo 'usage: make vertical-slice INPUT="/path/to/audio.wav" OUTPUT="/path/to/new evidence folder"' && exit 2)
	swift run -c release VerticalSliceCLI "$(INPUT)" --source vocal --prompt "make this clearer, warmer, and more controlled without sounding overprocessed" --revision "use less compression" --output "$(OUTPUT)"

project:
	xcodegen generate

au-host-probe:
	swift run -c release AudioUnitHostProbe

realtime-heap-probe:
	./scripts/run-realtime-heap-probe.sh

production-language-knowledge-check:
	python3 research/scripts/build-production-language-knowledge.py --check

tutor-procedure-knowledge-check:
	python3 research/scripts/audit-logic-tutor-procedure-knowledge.py
	python3 research/scripts/build-logic-tutor-procedure-knowledge.py --check

general-tutor-knowledge-check:
	python3 research/scripts/build-general-tutor-knowledge.py --check

general-tutor-knowledge-audit:
	python3 research/scripts/general-tutor-knowledge-pipeline.py audit

community-corpus-check:
	python3 research/scripts/preflight-tracksmith-corpus-package.py --incoming research/community_knowledge/packages/tracksmith-corpus-005-automation --dependency-map research/community_knowledge/dependency_maps/tracksmith-corpus-005-automation.json
	python3 research/scripts/preflight-tracksmith-corpus-package.py --incoming research/community_knowledge/packages/tracksmith-corpus-005-automation --dependency-map research/community_knowledge/dependency_maps/tracksmith-corpus-005-automation.json --disagreement-map research/community_knowledge/disagreement_maps/tracksmith-corpus-005-automation.json --strict-stage
	python3 research/scripts/preflight-tracksmith-corpus-package.py --incoming research/community_knowledge/packages/tracksmith-corpus-006-saturation-transient-shaping --dependency-map research/community_knowledge/dependency_maps/tracksmith-corpus-006-saturation-transient-shaping.json
	python3 research/scripts/preflight-tracksmith-corpus-package.py --incoming research/community_knowledge/packages/tracksmith-corpus-006-saturation-transient-shaping --dependency-map research/community_knowledge/dependency_maps/tracksmith-corpus-006-saturation-transient-shaping.json --disagreement-map research/community_knowledge/disagreement_maps/tracksmith-corpus-006-saturation-transient-shaping.json --strict-stage
	python3 research/scripts/preflight-tracksmith-corpus-package.py --incoming research/community_knowledge/packages/tracksmith-corpus-007-phase-polarity-stereo-imaging-panning --dependency-map research/community_knowledge/dependency_maps/tracksmith-corpus-007-phase-polarity-stereo-imaging-panning.json
	python3 research/scripts/preflight-tracksmith-corpus-package.py --incoming research/community_knowledge/packages/tracksmith-corpus-007-phase-polarity-stereo-imaging-panning --dependency-map research/community_knowledge/dependency_maps/tracksmith-corpus-007-phase-polarity-stereo-imaging-panning.json --disagreement-map research/community_knowledge/disagreement_maps/tracksmith-corpus-007-phase-polarity-stereo-imaging-panning.json --strict-stage
	python3 research/scripts/preflight-tracksmith-corpus-package.py --incoming research/community_knowledge/packages/tracksmith-corpus-008-editing-layering --dependency-map research/community_knowledge/dependency_maps/tracksmith-corpus-008-editing-layering.json
	python3 research/scripts/preflight-tracksmith-corpus-package.py --incoming research/community_knowledge/packages/tracksmith-corpus-008-editing-layering --dependency-map research/community_knowledge/dependency_maps/tracksmith-corpus-008-editing-layering.json --disagreement-map research/community_knowledge/disagreement_maps/tracksmith-corpus-008-editing-layering.json --strict-stage
	python3 research/scripts/import-community-vocal-quantization-v1.py --check
	python3 research/scripts/import-community-level-balancing-eq-v1.py --check
	python3 research/scripts/import-community-compression-arrangement-frequency-allocation-v1.py --check
	python3 research/scripts/import-community-reverb-delay-v1.py --check
	python3 research/scripts/import-community-automation-v1.py --check
	python3 research/scripts/import-community-saturation-transient-shaping-v1.py --check
	python3 research/scripts/stage-tracksmith-corpus-package.py --external research/community_knowledge/packages/tracksmith-corpus-005-automation --audit-staged
	python3 research/scripts/community_corpus_import.py --check --package tracksmith-corpus-005-automation
	python3 research/scripts/stage-tracksmith-corpus-package.py --external research/community_knowledge/packages/tracksmith-corpus-006-saturation-transient-shaping --audit-staged
	python3 research/scripts/community_corpus_import.py --check --package tracksmith-corpus-006-saturation-transient-shaping
	python3 research/scripts/stage-tracksmith-corpus-package.py --external research/community_knowledge/packages/tracksmith-corpus-007-phase-polarity-stereo-imaging-panning --audit-staged
	python3 research/scripts/community_corpus_import.py --check --package tracksmith-corpus-007-phase-polarity-stereo-imaging-panning
	python3 research/scripts/stage-tracksmith-corpus-package.py --external research/community_knowledge/packages/tracksmith-corpus-008-editing-layering --audit-staged
	python3 research/scripts/community_corpus_import.py --check --package tracksmith-corpus-008-editing-layering

community-phase-stereo-panning-check:
	python3 research/scripts/preflight-tracksmith-corpus-package.py --incoming research/community_knowledge/packages/tracksmith-corpus-007-phase-polarity-stereo-imaging-panning --dependency-map research/community_knowledge/dependency_maps/tracksmith-corpus-007-phase-polarity-stereo-imaging-panning.json --disagreement-map research/community_knowledge/disagreement_maps/tracksmith-corpus-007-phase-polarity-stereo-imaging-panning.json --strict-stage
	python3 research/scripts/stage-tracksmith-corpus-package.py --external research/community_knowledge/packages/tracksmith-corpus-007-phase-polarity-stereo-imaging-panning --audit-staged
	python3 research/scripts/community_corpus_import.py --check --package tracksmith-corpus-007-phase-polarity-stereo-imaging-panning

community-editing-layering-check:
	python3 research/scripts/preflight-tracksmith-corpus-package.py --incoming research/community_knowledge/packages/tracksmith-corpus-008-editing-layering --dependency-map research/community_knowledge/dependency_maps/tracksmith-corpus-008-editing-layering.json --disagreement-map research/community_knowledge/disagreement_maps/tracksmith-corpus-008-editing-layering.json --strict-stage
	python3 research/scripts/stage-tracksmith-corpus-package.py --external research/community_knowledge/packages/tracksmith-corpus-008-editing-layering --audit-staged
	python3 research/scripts/community_corpus_import.py --check --package tracksmith-corpus-008-editing-layering

community-gain-bus-loudness-check:
	python3 research/scripts/preflight-tracksmith-corpus-package.py --incoming research/community_knowledge/packages/tracksmith-corpus-009-gain-staging-bus-processing-loudness --dependency-map research/community_knowledge/dependency_maps/tracksmith-corpus-009-gain-staging-bus-processing-loudness.json --disagreement-map research/community_knowledge/disagreement_maps/tracksmith-corpus-009-gain-staging-bus-processing-loudness.json --standards-map research/community_knowledge/standards_maps/tracksmith-corpus-009-gain-staging-bus-processing-loudness.json --archive "$(P9_ARCHIVE)" --strict-stage
	python3 research/scripts/stage-tracksmith-corpus-package.py --external research/community_knowledge/packages/tracksmith-corpus-009-gain-staging-bus-processing-loudness --audit-staged
	python3 research/scripts/community_corpus_import.py --check --package tracksmith-corpus-009-gain-staging-bus-processing-loudness

community-corpus-preflight-selftest:
	python3 research/scripts/preflight-tracksmith-corpus-package.py --incoming research/community_knowledge/packages/tracksmith-corpus-008-editing-layering --dependency-map research/community_knowledge/dependency_maps/tracksmith-corpus-008-editing-layering.json --disagreement-map research/community_knowledge/disagreement_maps/tracksmith-corpus-008-editing-layering.json --self-test

community-automation-preflight:
	python3 research/scripts/preflight-tracksmith-corpus-package.py

community-saturation-transient-preflight:
	python3 research/scripts/preflight-tracksmith-corpus-package.py --incoming research/community_knowledge/packages/tracksmith-corpus-006-saturation-transient-shaping --dependency-map research/community_knowledge/dependency_maps/tracksmith-corpus-006-saturation-transient-shaping.json

general-tutor-evaluation:
	swift run -c release GeneralTutorEvaluation research/evaluation/TRACKSMITH_GENERAL_TUTOR_CORPUS_V1.json

tutor-evaluation:
	swift run -c release ProductionTutorEvaluation research/evaluation/TRACKSMITH_TUTOR_INTENT_CORPUS_V1.json

vocal-evaluation:
	swift run -c release VocalProductionEvaluation \
		--corpus research/evaluation/TRACKSMITH_VOCAL_SEMANTIC_CORPUS_V1.json \
		--failure-map research/evaluation/tracksmith-vocal-v1/failure-map.json \
		--output research/evaluation/tracksmith-vocal-v1/offline-evaluation-report-2026-08-08.json \
		--source-revision "$$(git rev-parse HEAD)" \
		--source-tree-state "$$(if test -z "$$(git status --porcelain)"; then echo clean; else echo dirty; fi)" \
		--toolchain "$$(swift --version | tr '\n' ' ')"

vocal-listening-selfcheck:
	swift run -c release VocalListeningStudyCLI selfcheck

native-build: project
	xcodebuild -project LogicAudioAssistant.xcodeproj -scheme CompanionMacApp -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO build

native-verify: native-build au-host-probe realtime-heap-probe

native-install:
	./scripts/install-development-build.sh

verify: project production-language-knowledge-check tutor-procedure-knowledge-check community-corpus-check general-tutor-knowledge-check general-tutor-knowledge-audit vocal-evaluation vocal-listening-selfcheck build test tutor-conversation-test au-host-probe
