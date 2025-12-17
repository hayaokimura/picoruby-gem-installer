#!/bin/sh
set -e

# picogem installer
# Usage: curl -fsSL https://raw.githubusercontent.com/hayaokimura/picoruby-gem-installer/main/install.sh | sh

REPO="hayaokimura/picoruby-gem-installer"
BINARY_NAME="picogem"

# Detect platform (linux-x86_64, darwin-x86_64, darwin-arm64)
detect_platform() {
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)

    # macOS is "Darwin" -> "darwin"
    if [ "$os" = "darwin" ]; then
        if [ "$arch" = "x86_64" ]; then
            echo "darwin-x86_64"
        elif [ "$arch" = "arm64" ]; then
            echo "darwin-arm64"
        else
            echo "Unsupported macOS architecture: $arch" >&2
            exit 1
        fi
    elif [ "$os" = "linux" ]; then
        if [ "$arch" = "x86_64" ]; then
            echo "linux-x86_64"
        else
            echo "Unsupported Linux architecture: $arch" >&2
            exit 1
        fi
    else
        echo "Unsupported OS: $os" >&2
        exit 1
    fi
}

# Get latest version from GitHub
get_latest_version() {
    curl -fsSI "https://github.com/${REPO}/releases/latest" 2>/dev/null \
        | grep -i "^location:" \
        | sed 's|.*/tag/||' \
        | tr -d '\r\n'
}

# Determine install directory
get_install_dir() {
    if [ -w "/usr/local/bin" ]; then
        echo "/usr/local/bin"
    else
        mkdir -p "$HOME/.local/bin"
        echo "$HOME/.local/bin"
    fi
}

# Main
main() {
    platform=$(detect_platform)
    version=$(get_latest_version)
    install_dir=$(get_install_dir)

    echo "Platform: $platform"
    echo "Version: $version"
    echo "Install to: $install_dir"

    # Download
    url="https://github.com/${REPO}/releases/download/${version}/${BINARY_NAME}-${platform}"
    echo "Downloading: $url"

    tmp_file=$(mktemp)
    trap 'rm -f "$tmp_file"' EXIT

    curl -fsSL "$url" -o "$tmp_file"
    chmod +x "$tmp_file"

    # Install (use sudo if needed)
    dest="${install_dir}/${BINARY_NAME}"
    if [ -w "$install_dir" ]; then
        mv "$tmp_file" "$dest"
    else
        echo "Need sudo to install to $install_dir"
        sudo mv "$tmp_file" "$dest"
        sudo chmod +x "$dest"
    fi

    echo "Installed: $dest"

    # Check PATH
    case ":$PATH:" in
        *":$install_dir:"*) ;;
        *) echo "Note: Add $install_dir to your PATH" ;;
    esac
}

main

