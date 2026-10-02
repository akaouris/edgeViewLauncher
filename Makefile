# Convenience wrappers around the npm scripts in package.json, which remain
# the source of truth for build commands. Run `make help` for the list.

# Equivalent of `. "$HOME/.cargo/env"`: rustup's default install location, so
# Tauri finds cargo even in a shell opened before Rust was installed.
export PATH := $(HOME)/.cargo/bin:$(PATH)

.DEFAULT_GOAL := help
.PHONY: help deps rust-toolchain backend frontend dev run test test-go test-frontend test-rust vet check build build-mac build-windows build-linux

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

deps: ## Install root and frontend npm dependencies
	npm ci
	cd frontend && npm ci

# npm writes node_modules/.package-lock.json on install, so these reinstall
# only when missing or when the lockfile changes.
node_modules/.package-lock.json: package-lock.json
	npm ci

frontend/node_modules/.package-lock.json: frontend/package-lock.json
	cd frontend && npm ci

NODE_DEPS := node_modules/.package-lock.json frontend/node_modules/.package-lock.json

rust-toolchain:
	@command -v cargo >/dev/null 2>&1 || { \
		echo "Rust (cargo) is required for Tauri. Install it with:"; \
		echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"; \
		echo "then open a new terminal (or run: source \$$HOME/.cargo/env)."; \
		exit 1; }

backend: ## Build the Go backend sidecar (macOS ARM64)
	npm run build:backend:mac

frontend: frontend/node_modules/.package-lock.json ## Build the frontend only
	npm run build:frontend

dev: $(NODE_DEPS) rust-toolchain backend ## Rebuild the backend, then start Vite + Tauri in dev mode
	npm run dev

run: dev ## Alias for dev

test: test-go test-frontend test-rust ## Run Go, frontend and Rust tests

test-go: ## Run Go tests
	go test ./...

test-frontend: frontend/node_modules/.package-lock.json ## Run frontend tests (non-watch)
	cd frontend && npm test -- --run

test-rust: rust-toolchain ## Run Rust tests
	cd src-tauri && cargo test

vet: ## Run go vet
	go vet ./...

check: vet test frontend backend ## Vet, test and build everything (pre-PR check)

build: build-mac ## Production build (macOS ARM64)

build-mac: $(NODE_DEPS) rust-toolchain ## Production build for macOS ARM64
	npm run build:mac

build-windows: $(NODE_DEPS) rust-toolchain ## Production build for Windows x64
	npm run build:windows

build-linux: $(NODE_DEPS) rust-toolchain ## Production build for Linux x64
	npm run build:linux
