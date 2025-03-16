PROJECT_NAME     := $(shell cargo read-manifest --manifest-path ./server/Cargo.toml | jq -r ".name")
PROJECT_VER      := $(shell cargo read-manifest --manifest-path ./server/Cargo.toml | jq -r ".version")
BIN_DIR          := ./bin
STATIC_DIR       := ./client/dist
NODE_MODULES_DIR := ./client/node_modules
PROJECT_SRCS     := $(shell find server/src -type f -iname *.rs) \
		    $(shell find server/src -type f -iname *.html) \
		    ./server/Cargo.toml \
		    ./server/Cargo.lock
STATIC_SRCS      := client/package.json \
		    client/pnpm-lock.yaml \
		    client/tailwind.config.js \
		    client/src/style.css \
		    $(shell find client/src -type f -iname *.js) \
		    $(shell find client/static -type f) \
		    $(shell find server/src -type f -iname *.html)
STATIC_OBJS      := $(addprefix $(BIN_DIR)/static/,index.js style.css icon.svg)
DIST_DIR          = $(BIN_DIR)/dist
DOCKER_TEMPLATE   = ./containers/Dockerfile.template
PACK_TARGETS      = x86-64-musl

fn_output_path    = $(BIN_DIR)/$(1)/$(PROJECT_NAME)
fn_target_path    = server/target/$(1)/$(PROJECT_NAME)

# RECIPIES:
# ==============================================================================
# build                : Generates server binary for the current system's CPU 
#                        architecture and OS.
# build-x86-64-musl    : linux/amd64, self contained with musl.
# build-x86-64-v3-musl : linux/amd64/v3, self contained with musl.
# build-x86-64-v4-musl : linux/amd64/v4, self contained with musl.
# build-aarch64-musl   : linux/arm64/v8, self contained with musl.
# build-aarch64-gnu    : linux/arm64/v8, glibc.
# build-armv6-musleabi : linux/arm/v6, self contained with musl, soft-floats.
# build-armv7-musleabi : linux/arm/v7, self contained with musl, soft-floats.
# build-riscv64gc-gnu  : linux/riscv64, glibc.
# build-client         : Generates front-end static files. Requires node and pnpm.
# build-all            : Cross compiles everything. Make sure host system has all
#                        the necessary libs and tools for arm, x86-64 and riscv.
# generate-dockerfiles : Generates dockerfiles for all supported architectures.
# pack                 : tar.gz all compiled targets under the bin directory.
# test                 : Calls available test suites.
# clean                : Clears all build directories.

.PHONY: build
build: $(call fn_output_path,release) build-client

$(call fn_output_path,release) &: $(PROJECT_SRCS)
	@echo "Building binaries for the current system's architecture."
	@cd ./server && cargo build --release
	@install -D $(call fn_target_path,release) $(call fn_output_path,release)

# x86-64 with different micro-architecture levels

.PHONY: build-x86-64-musl
build-x86-64-musl: $(call fn_output_path,x86-64-musl) build-client

$(call fn_output_path,x86-64-musl) &: $(PROJECT_SRCS)
	@echo "Building for x86_64-unknown-linux-musl"
	@cd ./server && \
		export RUSTFLAGS="-Clink-self-contained=yes -Clinker=rust-lld" && \
		cargo build --target=x86_64-unknown-linux-musl --release
	@install -D $(call fn_target_path,x86_64-unknown-linux-musl/release) \
		$(call fn_output_path,x86-64-musl)

.PHONY: build-client
build-client: $(STATIC_OBJS)

$(STATIC_OBJS) &: $(STATIC_SRCS)
	@pnpm install -C ./client/
	@pnpm run -C ./client/ build --outdir=../$(BIN_DIR)/static --minify

.PHONY: build-all
build-all: $(addprefix build-,$(PACK_TARGETS))

.PHONY: pack
pack: $(STATIC_OBJS)
	@install -d $(DIST_DIR)
	@for target in $(PACK_TARGETS); do \
		if [ -f "$(BIN_DIR)/$${target}/$(PROJECT_NAME)" ]; then \
			OUTPUT_TARGZ="$(DIST_DIR)/$(PROJECT_NAME)_$(PROJECT_VER)_$${target}.tar.gz"; \
			cp -r "$(BIN_DIR)/static" "$(BIN_DIR)/$${target}"; \
			tar -czf "$${OUTPUT_TARGZ}" -C "$(BIN_DIR)/" "$${target}"; \
			echo "Packed $${target}.tar.gz"; \
			sha256sum "$${OUTPUT_TARGZ}" > "$${OUTPUT_TARGZ}.sha256"; \
			echo "Generated $${target}.tar.gz.sha256"; \
		fi; \
	done;

.PHONY: test
test:
	@cd ./server && cargo test

.PHONY: generate-dockerfiles
generate-dockerfiles: 
	@echo "amd64.Dockerfile"
	@sed -e 's/{BIN_DIR}/x86-64-musl/g' \
		-e 's/{PLATFORM}/linux\/amd64/g' \
		-e 's/{BUSYBOX_LABEL}/stable-musl/g' \
		"$(DOCKER_TEMPLATE)" > ./containers/amd64.Dockerfile
	@echo "Generating annotation.conf"
	@CARGO_MANIFEST=$$(cargo read-manifest --manifest-path ./server/Cargo.toml); \
	echo "VERSION=\"$$(echo -n "$${CARGO_MANIFEST}" | jq -r ".version")\"" > ./containers/annotation.conf; \
	echo "HOME_URL=\"$$(echo -n "$${CARGO_MANIFEST}" | jq -r ".homepage")\"" >> ./containers/annotation.conf; \
	echo "NAME=\"$$(echo -n "$${CARGO_MANIFEST}" | jq -r ".name")\"" >> ./containers/annotation.conf; \
	echo "LICENSES=\"$$(echo -n "$${CARGO_MANIFEST}" | jq -r ".license")\"" >> ./containers/annotation.conf; \
	echo "AUTHORS=\"$$(echo -n "$${CARGO_MANIFEST}" | jq -r '.authors | join(" ")')\"" >> ./containers/annotation.conf; \
	echo "DOCUMENTATION=\"$$(echo -n "$${CARGO_MANIFEST}" | jq -r ".documentation")\"" >> ./containers/annotation.conf; \
	echo "SOURCE=\"$$(echo -n "$${CARGO_MANIFEST}" | jq -r ".repository")\"" >> ./containers/annotation.conf; \
	echo "DESCRIPTION=\"$$(echo -n "$${CARGO_MANIFEST}" | jq -r ".description")\"" >> ./containers/annotation.conf; \
	echo "REVISION=\"$$(git rev-parse --verify HEAD)\"" >> ./containers/annotation.conf;
	
.PHONY: clean
clean:
	@echo "Cleaning artifacts"
	@cd server && cargo clean
	@if [ -d "$(BIN_DIR)" ]; then rm -r "$(BIN_DIR)"; fi;
	@if [ -d "$(STATIC_DIR)" ]; then rm -r "$(STATIC_DIR)"; fi;
	@if [ -d "$(NODE_MODULES_DIR)" ]; then rm -r "$(NODE_MODULES_DIR)"; fi;
	@echo "Clean completed"
