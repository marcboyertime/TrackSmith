.PHONY: general-tutor-knowledge-audit build test demo demo-audio preview-demo audition vertical-slice project au-host-probe realtime-heap-probe production-language-knowledge-check tutor-procedure-knowledge-check tutor-evaluation general-tutor-knowledge-check general-tutor-knowledge-audit general-tutor-evaluation native-build native-verify native-install verify

build:
	swift build -c release

test:
	swift run -c release TestRunner

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

general-tutor-evaluation:
	swift run -c release GeneralTutorEvaluation research/evaluation/TRACKSMITH_GENERAL_TUTOR_CORPUS_V1.json

tutor-evaluation:
	swift run -c release ProductionTutorEvaluation research/evaluation/TRACKSMITH_TUTOR_INTENT_CORPUS_V1.json

native-build: project
	xcodebuild -project LogicAudioAssistant.xcodeproj -scheme CompanionMacApp -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO build

native-verify: native-build au-host-probe realtime-heap-probe

native-install:
	./scripts/install-development-build.sh

verify: project production-language-knowledge-check tutor-procedure-knowledge-check general-tutor-knowledge-check general-tutor-knowledge-audit build test au-host-probe
