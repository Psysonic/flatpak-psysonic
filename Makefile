# Makefile for building, running and cleaning the Flatpak package

FLATPACK_ID = io.github.psychotoxical.psysonic
FILE_YAML = ${FLATPACK_ID}.yaml
FILE_METAINFO = ${FLATPACK_ID}.metainfo.xml
FILE_FLATPAK = ${FLATPACK_ID}.flatpak

COMMIT_HASH = 'e06f88b8d4eef0d32a76191d376735cb3c079117'

OPTS = --arch=x86_64 --force-clean --user --verbose
OPTS_INSTALL = ${OPTS} --install
OPTS_FULL_INSTALL = ${OPTS_INSTALL} --install-deps-from=flathub

BUILD_PATH=build
YARN_BIN=$(shell which yarnpkg || which yarn)

PACKAGE_MANAGER = $(shell if command -v apt &> /dev/null; then echo "apt"; elif command -v dnf &> /dev/null; then echo "dnf"; else echo "unknown"; fi)

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
	flatpak install -y --user flathub org.gnome.Platform/x86_64/50
	flatpak install -y --user flathub org.gnome.Sdk/x86_64/50
	flatpak install -y --user flathub org.electronjs.Electron2.BaseApp//25.08
	flatpak install -y --user flathub org.freedesktop.Sdk//25.08
	flatpak install -y --user flathub org.freedesktop.Sdk.Extension.node26/x86_64/50
	flatpak install -y --user flathub org.gnome.Platform//46
	flatpak install -y --user flathub org.gnome.Sdk//46
	sudo ${PACKAGE_MANAGER} install -y flatpak-builder nodejs npm yarnpkg
	sudo npm install -g yarn@1.22.22
	sudo npm install -gpnpm@11.9.0

setup-venv: # Create a Python virtual environment
	python3 -m venv .venv

flatpak-node-generator: setup-venv # Install flatpak-node-generator in the virtual environment
	. .venv/bin/activate && \
	pip install flatpak-node-generator

flatpak-cargo-generator: setup-venv # Install flatpak-node-generator in the virtual environment
	. .venv/bin/activate && \
	pip install flatpak-cargo-generator

clean: # Clean up build artifacts
	rm -rf build .flatpak-builder export temp-psysonic ${FILE_FLATPAK}

clean-build-path: # Clean up only the build path
	rm -rf build .flatpak-builder/build

yarn-sources: flatpak-node-generator # Update node modules in the Flatpak package
	git clone https://github.com/Psychotoxical/psysonic.git temp-psysonic
	cd temp-psysonic && git checkout ${COMMIT_HASH}
	cd temp-psysonic && ${YARN_BIN} cache clean && rm -rf node_modules package-lock.json yarn.lock pnpm-lock.yaml
	${YARN_BIN} --cwd temp-psysonic install --production --mode=skip-build --network-timeout 100000
	cd temp-psysonic && npm cache clean -g --force --verbose && rm -rf node_modules package-lock.json pnpm-lock.yaml
	cd temp-psysonic && ../.venv/bin/flatpak-node-generator yarn -r yarn.lock --no-trim-index --electron-node-headers -o ../yarn-sources.json
	cp temp-psysonic/yarn.lock yarn.lock

cargo-sources: flatpak-cargo-generator
	git clone https://github.com/Psychotoxical/psysonic.git temp-psysonic
	cd temp-psysonic && git checkout ${COMMIT_HASH}
	cd temp-psysonic && ../.venv/bin/flatpak-cargo-generator -t -o ../cargo-sources.json src-tauri/Cargo.lock
	rm -rf temp-psysonic

generated-sources: flatpak-node-generator # Update node modules in the Flatpak package
	git clone https://github.com/Psychotoxical/psysonic.git temp-psysonic
	cd temp-psysonic && git checkout ${COMMIT_HASH}
	cd temp-psysonic && ../.venv/bin/flatpak-node-generator npm package-lock.json -o ../generated-sources.json
	rm -rf temp-psysonic

run: # Run the Flatpak application
	flatpak run ${FLATPACK_ID} --trace-deprecation --verbose --ostree-verbose --unhandled-rejections=strict --trace-warnings

submodule-shared-modules:
	git submodule add https://github.com/flathub/shared-modules.git

submodule-update-init:
	git submodule update --init

update-shared-modules:
	git submodule update --remote --merge shared-modules

remove: # Uninstall the Flatpak application
	flatpak remove -y ${FLATPACK_ID}

lint: # Lint the Flatpak YAML file
	flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest ${FILE_YAML}

lint-metainfo:
	flatpak run --command=flatpak-builder-lint org.flatpak.Builder appstream ${FILE_METAINFO}
