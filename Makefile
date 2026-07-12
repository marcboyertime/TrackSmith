.PHONY: build test demo project verify

build:
	swift build -c release

test:
	swift run -c release TestRunner

demo:
	swift run -c release CompanionApp make this clearer and more controlled

project:
	xcodegen generate

verify: project build test
