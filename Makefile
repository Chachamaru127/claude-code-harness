# Company AI Harness — root Makefile
#
# Usage:
#   make build      — Build bin/harness for the current platform
#   make test       — Run Go unit tests
#   make build-all  — Cross-compile for darwin-arm64, darwin-amd64, linux-amd64
#   make clean      — Remove bin/ build artifacts

.PHONY: build test build-all clean

build:
	bash scripts/build-harness.sh

test:
	cd go && go test ./...

build-all:
	cd go && bash scripts/build-all.sh

clean:
	rm -f bin/harness bin/harness-darwin-amd64 bin/harness-darwin-arm64 \
		bin/harness-linux-amd64 bin/harness-windows-amd64.exe bin/harness.exe
