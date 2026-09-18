APP_NAME = ScreenChest
BUILD_DIR = build
APP = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS = $(APP)/Contents
DEV_IDENTITY = ScreenChest Dev
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$(DEV_IDENTITY)\"" && echo "$(DEV_IDENTITY)" || echo "-")

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
	@echo "Built $(APP) (signed with: $(SIGN_IDENTITY))"

run: app
	open "$(APP)"

clean:
	rm -rf .build "$(BUILD_DIR)"
