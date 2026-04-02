.PHONY: build debug test run install clean lint format

build:
	swift build -c release
	mkdir -p bin
	cp .build/release/ktalk bin/ktalk

debug:
	swift build

test:
	swift test

run:
	swift run ktalk $(ARGS)

install: build
	cp bin/ktalk /usr/local/bin/ktalk

clean:
	swift package clean
	rm -rf bin

lint:
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint; \
	else \
		echo "swiftlint not found, skipping"; \
	fi

format:
	@if command -v swift-format >/dev/null 2>&1; then \
		swift-format -i -r Sources/; \
	else \
		echo "swift-format not found, skipping"; \
	fi
