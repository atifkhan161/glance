.PHONY: test test-quick test-full test-cache test-pipeline test-all-suites

SIM_ID := 4ABF9BBF-AB35-4739-B282-0EE19B2CE023
SIM_OS := 26.5
DEST := platform=iOS Simulator,id=$(SIM_ID),OS=$(SIM_OS)
PROJECT := Glance/Glance.xcodeproj
SCHEME := Glance

# Full test suite (~10min when stalled, ~20s scoped)
test:
	cd Glance && xcodebuild test-without-building \
		-project "$(PROJECT)" -scheme "$(SCHEME)" \
		-destination "$(DEST)" \
		CODE_SIGNING_ALLOWED=NO

# Fast path: unit tests only, no network smoke tests
test-quick:
	./scripts/test-area.sh Madrid PoGo Cache Theme GitHub

# Include network-dependent suites
test-full:
	./scripts/test-area.sh Madrid PoGo Cache Theme GitHub AiIntel SmartSearch Reddit

# Cache suites only (isolated from network tests)
test-cache:
	./scripts/test-area.sh CacheStore CacheTT

# Pipeline unit tests (no network)
test-pipeline:
	./scripts/test-area.sh Madrid PoGo GitHub AiIntel

# List all available suites
test-all-suites:
	./scripts/test-area.sh --list