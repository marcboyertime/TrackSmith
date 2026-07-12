.PHONY: build test demo demo-audio preview-demo project verify

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

project:
	xcodegen generate

verify: project build test
