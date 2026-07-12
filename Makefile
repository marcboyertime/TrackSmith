.PHONY: build test demo demo-audio preview-demo audition project au-host-probe native-build native-verify native-install verify

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

project:
	xcodegen generate

au-host-probe:
	swift run -c release AudioUnitHostProbe

native-build: project
	xcodebuild -project LogicAudioAssistant.xcodeproj -scheme CompanionMacApp -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO build

native-verify: native-build au-host-probe

native-install:
	./scripts/install-development-build.sh

verify: project build test au-host-probe
