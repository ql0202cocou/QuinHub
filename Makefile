# QuinHub 开发命令
# 约定见 doc/agents/engineering.md

FVM ?= fvm

# CARGO_TARGET_DIR 是 WSL（/mnt/d 慢盘）的绕法，macOS 用默认 target/
ifeq ($(shell uname),Darwin)
export JAVA_HOME ?= $(shell /usr/libexec/java_home -v 17)
else
export JAVA_HOME ?= $(HOME)/.jdk/temurin-17
export CARGO_TARGET_DIR ?= $(HOME)/cargo-targets/quinhub
endif

.PHONY: rust-test rust-lint flutter-test frb-codegen build-android fmt

rust-test:
	cd core && cargo test --workspace

rust-lint:
	cd core && cargo fmt --check && cargo clippy --workspace -- -D warnings

flutter-test:
	cd app && $(FVM) flutter analyze && $(FVM) flutter test

# 改 Rust bridge 后必须执行，并把生成物一并提交
# 配置读取 app/flutter_rust_bridge.yaml（rust_root / dart_output）
frb-codegen:
	cd app && flutter_rust_bridge_codegen generate

build-android:
	cd app && $(FVM) flutter build apk --debug

fmt:
	cd core && cargo fmt
	cd app && $(FVM) dart format lib test
