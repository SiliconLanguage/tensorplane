#!/bin/bash
# Note: Installs Go for MCP servers and bpftool for data-plane observability.
GO_VER="1.22.2"
wget https://go.dev/dl/go${GO_VER}.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go${GO_VER}.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
sudo apt-get install -y linux-headers-$(uname -r) bpftool clang llvm
