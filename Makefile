APP = build/ScreenChest.app

.PHONY: all app run install clean

all: app

app:
	scripts/build-app.sh

run: app
	open "$(APP)"

install:
	scripts/install.sh

clean:
	rm -rf .build build
