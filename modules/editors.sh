#!/usr/bin/env bash
set -euo pipefail

# modules/editors.sh
#
# PUBLIC:
#   install_vscode_deb
#   maybe_install_vscode
#   cursor_maybe_install_run
#
# ENV VARS USED:
#   DOTFILES_NONINTERACTIVE
#   INSTALL_VSCODE
#   INSTALL_CURSOR
#   CURSOR_INSTALL_FORCE
#
# SIDE EFFECTS:
#   May install VS Code via apt on Debian/Ubuntu
#   May install Cursor AppImage under ~/.local/bin and create desktop entry

# -----------------------------
# VS Code (Debian/Ubuntu, optional)
# -----------------------------

install_vscode_deb() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl not found; skipping VS Code install."
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not available; skipping VS Code install."
    return
  fi

  if ! command -v apt >/dev/null 2>&1 && ! command -v apt-get >/dev/null 2>&1; then
    echo "apt not found; VS Code install only supported on Debian/Ubuntu-like systems. Skipping."
    return
  fi

  echo "→ Adding Microsoft VS Code APT repository…"
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
    sudo gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg
  echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
    sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

  echo "→ Updating APT package cache…"
  sudo apt update

  echo "→ Installing VS Code…"
  sudo apt install -y code

  echo -e "${GREEN}✔ VS Code installed${RESET}"
}

maybe_install_vscode() {
  case "$(uname -s)" in
    Linux)
      if ! command -v apt >/dev/null 2>&1 && ! command -v apt-get >/dev/null 2>&1; then
        echo "Non-Debian-based Linux detected; skipping VS Code."
        return
      fi

      if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
        [[ "${INSTALL_VSCODE:-0}" == "1" ]] && install_vscode_deb
      else
        if command -v code >/dev/null 2>&1; then
          echo "VS Code (code) already installed; skipping."
        else
          read -rp "Install VS Code (code) via apt now? [y/N]: " ans || true
          [[ "$ans" =~ ^[Yy]$ ]] && install_vscode_deb
        fi
      fi
      ;;
    *)
      echo "Non-Linux system detected; skipping VS Code."
      ;;
  esac
}

# -----------------------------
# Cursor (Linux only, optional)
# -----------------------------

create_cursor_desktop_entry() {
  local desktop_dir="$HOME/.local/share/applications"
  local desktop_file="$desktop_dir/cursor.desktop"

  mkdir -p "$desktop_dir"
  cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Cursor
Comment=AI-first code editor
Exec=$HOME/.local/bin/Cursor.AppImage
Icon=cursor
Terminal=false
Categories=Development;TextEditor;IDE;
StartupWMClass=Cursor
EOF

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$desktop_dir" || true
  fi
  echo -e "${GREEN}✔ Cursor desktop entry created${RESET}"
}

install_cursor_linux() {
  command -v curl >/dev/null 2>&1 || { echo "curl not found; skipping Cursor install."; return; }

  # Skip by default on WSL unless forced
  if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
    if [[ "${CURSOR_INSTALL_FORCE:-0}" != "1" ]]; then
      echo "WSL detected; skipping Cursor install (set CURSOR_INSTALL_FORCE=1 to force)."
      return
    fi
  fi

  local install_dir="$HOME/.local/bin"
  local api_url="https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
  local appimage="$install_dir/Cursor.AppImage"

  echo "→ Fetching Cursor metadata…"
  mkdir -p "$install_dir"

  local json download_url
  json="$(curl -fsSL "$api_url" || true)"
  download_url="$(printf '%s' "$json" | grep -Po '"downloadUrl"\\s*:\\s*"\\K[^"]+' || true)"
  [[ -n "$download_url" ]] || { echo "Could not parse Cursor download URL; skipping."; return; }

  echo "→ Downloading Cursor from $download_url"
  curl -L --fail "$download_url" -o "$appimage"
  chmod +x "$appimage"
  echo -e "${GREEN}✔ Cursor installed${RESET}"

  create_cursor_desktop_entry
}

maybe_install_cursor() {
  case "$(uname -s)" in
    Linux)
      if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
        [[ "${INSTALL_CURSOR:-0}" == "1" ]] && install_cursor_linux
      else
        if [[ -f "$HOME/.local/bin/Cursor.AppImage" ]]; then
          echo "Cursor already present; ensuring desktop entry…"
          create_cursor_desktop_entry
        else
          read -rp "Install Cursor editor (Linux AppImage) now? [y/N]: " ans || true
          [[ "$ans" =~ ^[Yy]$ ]] && install_cursor_linux
        fi
      fi
      ;;
    *) : ;; # skip on macOS/others
  esac
}

cursor_maybe_install_run() {
  maybe_install_cursor
}


