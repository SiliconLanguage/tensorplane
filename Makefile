.PHONY: all deps build clean run-control run-data

all: deps build

deps:
	@echo "==> Fetching Go dependencies..."
	cd control_plane && go mod tidy && go mod download
	@echo "==> Fetching Rust dependencies..."
	cd data_plane && cargo fetch

build:
	@echo "==> Building Go Control Plane..."
	cd control_plane && go build -o bin/tensorplaned ./cmd/tensorplaned
	@echo "==> Building Rust Data Plane..."
	cd data_plane && cargo build --release

run-control:
	cd control_plane && go run ./cmd/tensorplaned

run-data:
	cd data_plane && cargo run -p usrbio

clean:
	@echo "==> Cleaning artifacts..."
	rm -rf control_plane/bin
	cd data_plane && cargo clean
