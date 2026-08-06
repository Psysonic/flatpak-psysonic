# Makefile for building, running and cleaning the Flatpak package

FLATPACK_ID = io.github.psychotoxical.psysonic
FILE_YAML = ${FLATPACK_ID}.yaml
FILE_METAINFO = ${FLATPACK_ID}.metainfo.xml
FILE_FLATPAK = ${FLATPACK_ID}.flatpak

OPTS = --arch=x86_64 --force-clean --user --verbose --disable-rofiles-fuse --disable-cache
OPTS_INSTALL = ${OPTS} --install
OPTS_FULL_INSTALL = ${OPTS_INSTALL} --install-deps-from=flathub

BUILD_PATH=build
YARN_BIN=$(shell which yarnpkg || which yarn)

build-install: clean # Build the Flatpak package with dependencies already installed
	flatpak-builder ${OPTS_INSTALL} ${BUILD_PATH} ${FILE_YAML}

build: clean # Build the Flatpak package without installing
	flatpak-builder ${OPTS} ${BUILD_PATH} ${FILE_YAML}

build-full-install: clean # Build the Flatpak package
	flatpak-builder ${OPTS_FULL_INSTALL} ${BUILD_PATH} ${FILE_YAML}

build-fast-install: clean-build-path # Build the Flatpak package without cleaning .flatpak-builder directory
	flatpak-builder --user --install ${BUILD_PATH} ${FILE_YAML}

build-aarch64: clean-build-path # Build the Flatpak package for aarch64
	flatpak-builder --user --arch=aarch64 ${BUILD_PATH} ${FILE_YAML}

build-export: build flatpak-export # Build and export the Flatpak package
	@echo "[i] Flatpak package built and exported to ${FILE_FLATPAK}"

flatpak-export: # Export the built Flatpak package to the local repository
	flatpak build-export export ${BUILD_PATH}
	flatpak build-bundle export ${FILE_FLATPAK} ${FLATPACK_ID}

install-dependencies-locally: # Install Flatpak runtime and SDK dependencies locally
	flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
	flatpak install -y --user flathub org.freedesktop.Platform//25.08
	flatpak install -y --user flathub org.electronjs.Electron2.BaseApp//25.08
	flatpak install -y --user flathub org.freedesktop.Sdk//25.08
	flatpak install -y --user flathub org.freedesktop.Sdk.Extension.node24//25.08
	flatpak install -y --user flathub org.gnome.Platform//46
	flatpak install -y --user flathub org.gnome.Sdk//46
	sudo apt install -y flatpak-builder nodejs npm yarnpkg
	sudo npm install -g yarn@1.22.22
	sudo npm install -gpnpm@11.9.0

setup-venv: # Create a Python virtual environment
	python3 -m venv .venv

flatpak-node-generator: setup-venv # Install flatpak-node-generator in the virtual environment
	. .venv/bin/activate && \
	pip install flatpak-node-generator

clean: # Clean up build artifacts
	rm -rf .flatpak-builder ${BUILD_PATH} export ${FILE_FLATPAK}

clean-build-path: # Clean up only the build path
	rm -rf ${BUILD_PATH}

run: # Run the Flatpak application
	flatpak run ${FLATPACK_ID} --trace-deprecation --verbose --ostree-verbose --unhandled-rejections=strict --trace-warnings

remove: # Uninstall the Flatpak application
	flatpak remove -y ${FLATPACK_ID}

lint: # Lint the Flatpak YAML file
	flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest ${FILE_YAML}

lint-metainfo:
	flatpak run --command=flatpak-builder-lint org.flatpak.Builder appstream ${FILE_METAINFO}

sync-aonsoku:
	cp -v io.github.psysonic.aonsoku.metainfo.xml ../aonsoku/flatpak
	cp -v io.github.psysonic.aonsoku.desktop ../aonsoku/flatpak