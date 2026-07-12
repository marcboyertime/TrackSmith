.PHONY: build test demo demo-audio preview-demo audition project verify

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

verify: project build test
