.PHONY: build run clean release

build:
	swift build

run: build
	open .build/debug/Glance

clean:
	swift package clean

release:
	swift build -c release
	@echo "Binary: .build/release/Glance"
