# TensorPlane Unified Build System
# Targets: Control Plane (Go), Data Plane (Rust), Data Plane (C++ / io_uring), Docs

.PHONY: all deps build clean run-control run-data data-plane-cpp provision-check docs clean-docs

# --- Default Build ---
all: deps build data-plane-cpp docs

# --- Dependency Management ---
deps:
	@echo "==> Fetching Go dependencies..."
	cd control_plane && go mod tidy && go mod download
	@echo "==> Fetching Rust dependencies..."
	cd data_plane && cargo fetch

# --- Compilation ---
build:
	@echo "==> Building Go Control Plane..."
	mkdir -p bin
	cd control_plane && go build -o ../bin/tensorplaned ./cmd/tensorplaned
	@echo "==> Building Rust Data Plane (Release)..."
	cd data_plane && cargo build --release

# High-Performance C++ Data Plane (io_uring)
data-plane-cpp:
	@echo "==> Building C++ User-space Data Plane..."
	mkdir -p bin
	g++ -O3 -march=native dev_cpp_dataplane/dataplane.cpp -luring -o bin/dataplane_emu

# --- Documentation ---
docs:
	@echo "==> Building Sphinx Documentation..."
	cd docs && make html

clean-docs:
	@echo "==> Cleaning Documentation..."
	cd docs && make clean

# --- Execution ---
run-control:
	cd control_plane && go run ./cmd/tensorplaned

run-data:
	cd data_plane && cargo run -p usrbio

# --- Infrastructure & Quality ---
provision-check:
	@echo "==> Verifying local provisioning scripts..."
	shellcheck provision/**/*.sh

clean: clean-docs
	@echo "==> Cleaning artifacts..."
	rm -rf bin/*
	rm -rf control_plane/bin
	cd data_plane && cargo clean
