.PHONY: help lint lint-fix format check setup-hooks build test test-host
.DEFAULT_GOAL := help

help:
	@echo "Project targets:"
	@echo "  make build        swift build"
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

setup-hooks:
	git config core.hooksPath Scripts/git-hooks
	@echo "Git hooks configured to Scripts/git-hooks/"

build:
	swift build

# Canonical test run (iOS simulator, exercises the UIKit-gated image encoder).
test:
	xcodebuild test -scheme Sophon-Package -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -quiet

# Fast host-side run (Foundation-only surface; skips UIKit-gated code).
test-host:
	swift test
