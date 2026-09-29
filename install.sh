#!/usr/bin/env bash

# Config variables (defined here, not sourced from src/config.sh, because when
# this script is run through curl there is no config.sh on disk yet)
PHARO_IMAGES_DIR="${PHARO_IMAGES_DIR:-$HOME/Documents/PharoCliImages}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.pharo-cli}"
REPO_URL="https://github.com/jordanmontt/pharo-cli.git"
ZSHRC="${ZSHRC:-$HOME/.zshrc}"
BASH_PROFILE="${BASH_PROFILE:-$HOME/.bash_profile}"


# Check for Homebrew
if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Check and install external dependencies
# Install fzf
if ! command -v fzf &> /dev/null; then
    echo "fzf not found, installing..."
    brew install fzf
fi
# Install trash
if ! command -v trash &> /dev/null; then
    echo "trash not found, installing..."
    brew install --HEAD macmade/tap/trash
fi

# Clone the repository if not already present
if [ -d "$INSTALL_DIR" ]; then
    echo "pharo-cli already exists at $INSTALL_DIR. Updating..."
    cd "$INSTALL_DIR" && git pull
else
    echo "Cloning pharo-cli to $INSTALL_DIR..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Create PharoImages directory
if [ ! -d "$PHARO_IMAGES_DIR" ]; then
    echo "Creating PharoImages directory at $PHARO_IMAGES_DIR..."
    mkdir -p "$PHARO_IMAGES_DIR"
fi

# Update PATH in .zshrc or .bash_profile
PATH_LINE="export PATH=\"\$PATH:$INSTALL_DIR/bin\""

if [ -f "$ZSHRC" ]; then
    if ! grep -Fx "$PATH_LINE" "$ZSHRC" >/dev/null; then
        echo "Adding pharo-cli to PATH variable in $ZSHRC..."
        echo "$PATH_LINE" >> "$ZSHRC"
    else
        echo "PATH already updated in $ZSHRC."
    fi
elif [ -f "$BASH_PROFILE" ]; then
    if ! grep -Fx "$PATH_LINE" "$BASH_PROFILE" >/dev/null; then
        echo "Adding pharo-cli to PATH variable in $BASH_PROFILE..."
        echo "$PATH_LINE" >> "$BASH_PROFILE"
    else
        echo "PATH already updated in $BASH_PROFILE."
    fi
else
    echo "Creating $ZSHRC and adding PATH..."
    echo "$PATH_LINE" >> "$ZSHRC"
fi

# Source the updated shell configuration
if [ -n "$ZSH_VERSION" ]; then
    source "$ZSHRC"
elif [ -n "$BASH_VERSION" ]; then
    source "$BASH_PROFILE"
fi

# Finished
echo "Installation complete."
echo "Run 'pharo --help' to get started."