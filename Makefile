EXTENSION_UUID := acer-thermal-cachy@local
BUILD_DIR := build
DIST_DIR := dist
EXTENSION_DIR := $(BUILD_DIR)/$(EXTENSION_UUID)
LEGACY_EXTENSION_DIR := $(BUILD_DIR)/$(EXTENSION_UUID)-legacy

.PHONY: all clean dist install-local uninstall-local check

all: dist

$(EXTENSION_DIR):
	mkdir -p "$(EXTENSION_DIR)"
	cp extension/metadata.json extension/extension.js "$(EXTENSION_DIR)/"

$(LEGACY_EXTENSION_DIR):
	mkdir -p "$(LEGACY_EXTENSION_DIR)"
	cp extension-legacy/metadata.json extension-legacy/extension.js "$(LEGACY_EXTENSION_DIR)/"

dist: clean $(EXTENSION_DIR) $(LEGACY_EXTENSION_DIR)
	mkdir -p "$(DIST_DIR)"
	cd "$(BUILD_DIR)" && zip -qr "../$(DIST_DIR)/$(EXTENSION_UUID).zip" "$(EXTENSION_UUID)"
	rm -rf "$(BUILD_DIR)/$(EXTENSION_UUID)"
	mv "$(LEGACY_EXTENSION_DIR)" "$(EXTENSION_DIR)"
	cd "$(BUILD_DIR)" && zip -qr "../$(DIST_DIR)/$(EXTENSION_UUID)-gnome-42-44.zip" "$(EXTENSION_UUID)"

install-local:
	./install.sh --local

uninstall-local:
	./uninstall.sh --local

check:
	bash -n install.sh
	bash -n uninstall.sh
	bash -n install-sudoers.sh
	bash -n uninstall-sudoers.sh
	bash -n diagnose.sh
	bash -n backend/thermal-control.sh
	node --check extension/extension.js
	node --check extension-legacy/extension.js
	python3 -m json.tool extension/metadata.json >/dev/null
	python3 -m json.tool extension-legacy/metadata.json >/dev/null

clean:
	rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"
