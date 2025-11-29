#!/usr/bin/env bash
set -euo pipefail

# modules/antigravity.sh
#
# PUBLIC:
#   antigravity_maybe_install_run
#
# ENV VARS USED:
#   DOTFILES_NONINTERACTIVE
#   INSTALL_ANTIGRAVITY
#
# SIDE EFFECTS:
#   May install Antigravity via apt and adjust zsh completion ownership

install_antigravity_deb() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl not found; skipping Antigravity install."
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not available; skipping Antigravity install."
    return
  fi

  if ! command -v apt >/dev/null 2>&1 && ! command -v apt-get >/dev/null 2>&1; then
    echo "apt not found; Antigravity install only supported on Debian/Ubuntu-like systems. Skipping."
    return
  fi

  echo "→ Configuring Antigravity APT repository…"
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg
  echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
    sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null

  echo "→ Updating APT package cache…"
  sudo apt update

  echo "→ Installing Antigravity…"
  sudo apt install -y antigravity

  # Ensure Antigravity zsh completion file has correct ownership
  local ag_completion="/usr/share/zsh/vendor-completions/_antigravity"
  if [ -f "$ag_completion" ]; then
    echo "→ Fixing Antigravity zsh completion ownership…"
    sudo chown root:root "$ag_completion" || true
  fi

  echo -e "${GREEN}✔ Antigravity installed${RESET}"
}

maybe_install_antigravity() {
  case "$(uname -s)" in
    Linux)
      if ! command -v apt >/dev/null 2>&1 && ! command -v apt-get >/dev/null 2>&1; then
        echo "Non-Debian-based Linux detected; skipping Antigravity."
        return
      fi

      if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
        [[ "${INSTALL_ANTIGRAVITY:-0}" == "1" ]] && install_antigravity_deb
      else
        if command -v antigravity >/dev/null 2>&1; then
          echo "Antigravity already installed; skipping."
        else
          read -rp "Install Antigravity (via apt, Debian/Ubuntu only)? [y/N]: " ans || true
          [[ "$ans" =~ ^[Yy]$ ]] && install_antigravity_deb
        fi
      fi
      ;;
    *)
      echo "Non-Linux system detected; skipping Antigravity."
      ;;
  esac
}

antigravity_maybe_install_run() {
  maybe_install_antigravity
}


