#!/bin/bash
set -e

echo "==========================================="
echo " Bootstrapping TensorPlane Dev Environment"
echo "==========================================="

# 1. Check for and install mise
if ! command -v mise &> /dev/null; then
    echo "=> 'mise' not found. Downloading and installing..."
    curl https://mise.run | sh
    
    # Hook into .bashrc if not already present
    if ! grep -q "mise activate bash" ~/.bashrc; then
        echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
        echo "=> Added mise hook to ~/.bashrc"
    fi
    
    # Temporarily add to PATH so the rest of this script works
    export PATH="$HOME/.local/bin:$PATH"
else
    echo "=> 'mise' is already installed."
fi

# 2. Activate mise for the current script session
eval "$(mise activate bash)"

# 3. Trust the local mise.toml file (solves the untrusted config error)
echo "=> Trusting the local repository configuration..."
mise trust

# 4. Install the exact toolchains (Go 1.22, Rust stable)
echo "=> Installing Go and Rust toolchains..."
mise install

# 5. Fetch project dependencies using the Makefile we created earlier
if [ -f "Makefile" ]; then
    echo "=> Fetching Go and Rust package dependencies..."
    make deps
else
    echo "=> Makefile not found. Skipping 'make deps'."
fi

echo "==========================================="
echo " Setup Complete! "
echo " "
echo " IMPORTANT: Run the following command to "
echo " update your current terminal session: "
echo " "
echo " source ~/.bashrc "
echo "==========================================="