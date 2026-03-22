.PHONY: build run clean release app

APP_NAME = Glance
APP_DIR = .build/$(APP_NAME).app
BINARY = .build/debug/$(APP_NAME)

build:
	swift build

app: build
	@mkdir -p "$(APP_DIR)/Contents/MacOS"
	@cp $(BINARY) "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	@/usr/libexec/PlistBuddy -c "Clear dict" "$(APP_DIR)/Contents/Info.plist" 2>/dev/null; \
	/usr/libexec/PlistBuddy \
		-c "Add :CFBundleExecutable string $(APP_NAME)" \
		-c "Add :CFBundleIdentifier string com.glance.app" \
		-c "Add :CFBundleName string $(APP_NAME)" \
		-c "Add :CFBundlePackageType string APPL" \
		"$(APP_DIR)/Contents/Info.plist"

run: app
	"$(APP_DIR)/Contents/MacOS/$(APP_NAME)"

clean:
	swift package clean
	rm -rf "$(APP_DIR)"

release:
	swift build -c release
	@echo "Binary: .build/release/$(APP_NAME)"
