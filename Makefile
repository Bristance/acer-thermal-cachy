PLASMOID_ID := org.local.acerthermal.cachy
BUILD_DIR := build
DIST_DIR := dist
PLASMOID_DIR := $(BUILD_DIR)/$(PLASMOID_ID)

.PHONY: all clean dist install-local uninstall-local check

all: dist

$(PLASMOID_DIR):
	mkdir -p "$(PLASMOID_DIR)/contents/ui"
	cp plasmoid/metadata.json "$(PLASMOID_DIR)/metadata.json"
	cp plasmoid/contents/ui/main.qml "$(PLASMOID_DIR)/contents/ui/main.qml"

dist: clean $(PLASMOID_DIR)
	mkdir -p "$(DIST_DIR)"
	cd "$(BUILD_DIR)" && zip -qr "../$(DIST_DIR)/$(PLASMOID_ID).plasmoid" "$(PLASMOID_ID)"

install-local:
	./install.sh --local

uninstall-local:
	./uninstall.sh --local

check:
	bash -n install.sh
	bash -n uninstall.sh
	bash -n add-to-panel.sh
	bash -n install-sudoers.sh
	bash -n uninstall-sudoers.sh
	bash -n diagnose.sh
	bash -n backend/thermal-control.sh
	python3 -m json.tool plasmoid/metadata.json >/dev/null
	test "$$(python3 -c 'import json; print(json.load(open("plasmoid/metadata.json"))["X-Plasma-API-Minimum-Version"])')" = "6.0"

clean:
	rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"
