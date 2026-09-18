APP_NAME = ScreenSail
BUILD_DIR = build
APP = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS = $(APP)/Contents
SIGN_IDENTITY ?= -

.PHONY: all app run clean

all: app

app:
	swift build -c release
	rm -rf "$(APP)"
	mkdir -p "$(CONTENTS)/MacOS" "$(CONTENTS)/Resources"
	cp ".build/release/$(APP_NAME)" "$(CONTENTS)/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(CONTENTS)/Info.plist"
	printf 'APPL????' > "$(CONTENTS)/PkgInfo"
	codesign --force --sign "$(SIGN_IDENTITY)" "$(APP)"
	@echo "Built $(APP)"

run: app
	open "$(APP)"

clean:
	rm -rf .build "$(BUILD_DIR)"
