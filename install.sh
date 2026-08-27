#!/bin/sh
# install.sh — download and install fir for the current platform.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kfet/fir-dist/main/install.sh | sh
#
# Binaries are distributed from the public kfet/fir-dist repo, so no
# authentication is required.
#
# Options (environment variables):
#   INSTALL_DIR  — where to install (default: /usr/local/bin, or ~/.local/bin if no write access)
#   VERSION      — specific version to install (default: latest)

set -e

REPO="kfet/fir-dist"
BINARY="fir"

# Scratch state, removed by the cleanup trap below: TMP is the downloaded
# binary, PROBE_DIR holds the duplicate-install scan's per-candidate results.
TMP=""
PROBE_DIR=""

cleanup() {
    [ -n "$TMP" ] && rm -f "$TMP"
    [ -n "$PROBE_DIR" ] && rm -rf "$PROBE_DIR"
    return 0
}

trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
trap 'cleanup; exit 129' HUP

# --------------------------------------------------------------------------
# Detect platform
# --------------------------------------------------------------------------

detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case "$OS" in
        darwin) ;;
        linux)  ;;
        *)
            echo "Error: unsupported OS: $OS" >&2
            echo "  Build from source: go install github.com/$REPO/cmd/fir@latest" >&2
            exit 1
            ;;
    esac

    case "$ARCH" in
        x86_64|amd64)       ARCH="amd64" ;;
        arm64|aarch64)      ARCH="arm64" ;;
        armv6l)             ARCH="armv6"  ;;
        armv7l)             ARCH="armv6"  ;; # ARMv6 binary runs on ARMv7
        *)
            echo "Error: unsupported architecture: $ARCH" >&2
            echo "  Build from source: go install github.com/$REPO/cmd/fir@latest" >&2
            exit 1
            ;;
    esac

    PLATFORM="${OS}-${ARCH}"
    ASSET_NAME="fir-${PLATFORM}"
}

# --------------------------------------------------------------------------
# Resolve version
# --------------------------------------------------------------------------

resolve_version() {
    if [ -n "$VERSION" ]; then
        # Ensure v prefix
        case "$VERSION" in
            v*) TAG="$VERSION" ;;
            *)  TAG="v$VERSION" ;;
        esac
        return
    fi

    # Fetch latest tag from the public releases API.
    URL="https://api.github.com/repos/$REPO/releases/latest"
    TAG=$(curl -fsSL "$URL" 2>/dev/null \
        | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"//;s/".*//')

    if [ -z "$TAG" ]; then
        echo "Error: could not determine latest version from $URL" >&2
        echo "  Check your network or install from source:" >&2
        echo "  go install github.com/kfet/fir/cmd/fir@latest" >&2
        exit 1
    fi
}

# --------------------------------------------------------------------------
# Resolve install directory
# --------------------------------------------------------------------------

resolve_install_dir() {
    if [ -n "$INSTALL_DIR" ]; then
        return
    fi

    if [ -w /usr/local/bin ]; then
        INSTALL_DIR="/usr/local/bin"
    elif [ -d "$HOME/.local/bin" ] || mkdir -p "$HOME/.local/bin" 2>/dev/null; then
        INSTALL_DIR="$HOME/.local/bin"
    else
        INSTALL_DIR="/usr/local/bin"
    fi
}

# --------------------------------------------------------------------------
# Download
# --------------------------------------------------------------------------

download() {
    DEST="$INSTALL_DIR/$BINARY"
    TMP=$(mktemp "${TMPDIR:-/tmp}/fir-install.XXXXXX")

    echo "Installing fir $TAG ($PLATFORM) to $INSTALL_DIR..."

    ASSET_URL="https://github.com/$REPO/releases/download/$TAG/$ASSET_NAME"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$ASSET_URL" -o "$TMP"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$ASSET_URL" -O "$TMP"
    else
        echo "Error: neither curl nor wget found" >&2
        exit 1
    fi

    install_binary
}

install_binary() {
    chmod +x "$TMP"

    # Try direct move; fall back to sudo
    if [ -w "$INSTALL_DIR" ]; then
        mv "$TMP" "$DEST"
    else
        echo "Need sudo to write to $INSTALL_DIR"
        sudo mv "$TMP" "$DEST"
    fi
    TMP=""

    echo "Successfully installed fir $TAG to $DEST"
    install_completions

    echo ""
    echo "Run 'fir --version' to verify."

    # Check if INSTALL_DIR is in PATH
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) ;;
        *)
            echo ""
            echo "Note: $INSTALL_DIR is not in your PATH."
            echo "Add it:  export PATH=\"$INSTALL_DIR:\$PATH\""
            ;;
    esac
}

# --------------------------------------------------------------------------
# Warn about other fir installs
# --------------------------------------------------------------------------
#
# Several fir binaries on one machine diverge silently: PATH order decides
# which one runs, and `fir update` only ever rewrites the copy it was
# launched from. Scan every PATH entry plus the well-known install
# locations, collapse symlinks so one file reached two ways is not counted
# twice, and report when more than one distinct binary exists.
#
# This is advisory only: no network, and it never changes the exit status.

# Best-effort symlink resolution; falls back to the path as given.
resolve_link() {
    if command -v realpath >/dev/null 2>&1; then
        realpath "$1" 2>/dev/null || echo "$1"
    elif command -v readlink >/dev/null 2>&1 && readlink -f "$1" >/dev/null 2>&1; then
        readlink -f "$1"
    else
        echo "$1"
    fi
}

check_duplicate_installs() {
    # Directories to look in: everything on PATH, plus the spots we know
    # about even when they are not on PATH.
    dirs=$(printf '%s' "$PATH" | tr ':' '\n')
    dirs="$dirs
/usr/local/bin
$HOME/.local/bin
$HOME/go/bin
$HOME/bin
$INSTALL_DIR"

    # Ask brew where it lives rather than guessing /usr/local vs /opt/homebrew.
    if command -v brew >/dev/null 2>&1; then
        brew_prefix=$(brew --prefix 2>/dev/null || true)
        if [ -n "$brew_prefix" ]; then
            dirs="$dirs
$brew_prefix/bin"
        fi
    fi

    # What PATH actually resolves right now.
    active=$(command -v "$BINARY" 2>/dev/null || true)
    [ -n "$active" ] && active=$(resolve_link "$active")

    PROBE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/fir-probe.XXXXXX") || return 0

    seen=""
    count=0

    old_ifs=$IFS
    IFS='
'
    for dir in $dirs; do
        [ -n "$dir" ] || continue
        candidate="$dir/$BINARY"
        [ -f "$candidate" ] && [ -x "$candidate" ] || continue

        real=$(resolve_link "$candidate")
        case "
$seen" in
            *"
$real
"*) continue ;;
        esac
        seen="$seen$real
"

        count=$((count + 1))
        printf '%s\n' "$real" > "$PROBE_DIR/p.$count"

        # Probe versions concurrently, one background job per binary, so N
        # candidates cost one probe's wall time instead of N. FIR_NO_UPDATE_CHECK
        # keeps each probe local: fir >= 1.3 skips its release check, so nothing
        # here touches the network. Older binaries ignore it and may pause
        # briefly, but they all pause at the same time.
        (FIR_NO_UPDATE_CHECK=1 "$real" --version 2>/dev/null | head -1 > "$PROBE_DIR/v.$count") &
    done
    IFS=$old_ifs

    wait

    [ "$count" -gt 1 ] || return 0

    echo ""
    echo "Warning: $count fir binaries found on this system:"

    i=1
    while [ "$i" -le "$count" ]; do
        real=$(cat "$PROBE_DIR/p.$i")
        ver=$(cat "$PROBE_DIR/v.$i" 2>/dev/null)
        [ -n "$ver" ] || ver="unknown version"

        if [ "$real" = "$active" ]; then
            mark="<- PATH resolves this one"
        else
            mark="(shadowed)"
        fi

        echo "  $real  [$ver]  $mark"
        i=$((i + 1))
    done

    echo ""
    echo "Only the one PATH resolves is used, and 'fir update' only updates that"
    echo "copy — the others keep their old versions. Remove the extras (or put the"
    echo "directory you want first on PATH) to avoid running a stale fir."
}

# Install bash + zsh completion to per-user directories. We never sudo here —
# system-wide install is left to package managers (Homebrew etc.). Each shell
# is handled independently so a failure on one doesn't skip the other. The
# completion script is generated to a temp file first and only moved into
# place after a successful run, so an existing valid file is never replaced
# by an empty one if `fir completion` happens to error.
install_completions() {
    bash_dir="$HOME/.local/share/bash-completion/completions"
    zsh_dir="$HOME/.local/share/zsh/site-functions"

    if mkdir -p "$bash_dir" 2>/dev/null; then
        tmp=$(mktemp "${TMPDIR:-/tmp}/fir-completion.XXXXXX") || tmp=""
        if [ -n "$tmp" ] && "$DEST" completion bash > "$tmp" 2>/dev/null; then
            chmod 644 "$tmp"
            mv "$tmp" "$bash_dir/fir"
            echo "Installed bash completion: $bash_dir/fir"
        else
            [ -n "$tmp" ] && rm -f "$tmp"
        fi
    fi

    if mkdir -p "$zsh_dir" 2>/dev/null; then
        tmp=$(mktemp "${TMPDIR:-/tmp}/fir-completion.XXXXXX") || tmp=""
        if [ -n "$tmp" ] && "$DEST" completion zsh > "$tmp" 2>/dev/null; then
            chmod 644 "$tmp"
            mv "$tmp" "$zsh_dir/_fir"
            echo "Installed zsh completion:  $zsh_dir/_fir"
            echo "  (ensure '$zsh_dir' is on your zsh \$fpath before compinit)"
        else
            [ -n "$tmp" ] && rm -f "$tmp"
        fi
    fi
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

detect_platform
resolve_version
resolve_install_dir
download
check_duplicate_installs || true
