.PHONY: help lint lint-fix format check setup-hooks build build-strict test test-host
.DEFAULT_GOAL := help

help:
	@echo "Project targets:"
	@echo "  make build        swift build"
	@echo "  make build-strict swift build with warnings as errors (library + tests)"
	@echo "  make test         xcodebuild test on the iOS simulator (canonical)"
	@echo "  make test-host    swift test (fast, Foundation-only surface)"
	@echo "  make lint         Run SwiftLint"
	@echo "  make lint-fix     Run SwiftLint --fix"
	@echo "  make format       Run SwiftFormat (modifies files)"
	@echo "  make check        Strict lint + format check (CI gate)"
	@echo "  make setup-hooks  Install pre-commit hooks"

lint:
	swiftlint

lint-fix:
	swiftlint --fix

format:
	swiftformat .

check:
	swiftlint --strict
	swiftformat --lint .
	@if grep -Eiq 'DEVELOPMENT_?TEAM = "?[A-Za-z0-9]' Example/SophonExample.xcodeproj/project.pbxproj; then \
		echo "error: Example/SophonExample.xcodeproj carries a DEVELOPMENT_TEAM; keep it empty in the committed project"; exit 1; fi

setup-hooks:
	git config core.hooksPath Scripts/git-hooks
	@echo "Git hooks configured to Scripts/git-hooks/"

build:
	swift build

# Warnings-as-errors ratchet for the library and the test targets (host surface).
build-strict:
	swift build --build-tests -Xswiftc -warnings-as-errors

# Canonical test run (iOS simulator, exercises the UIKit-gated image encoder).
test:
	xcodebuild test -scheme Sophon-Package -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -quiet

# Fast host-side run (Foundation-only surface; skips UIKit-gated code).
test-host:
	swift test
