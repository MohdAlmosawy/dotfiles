#!/usr/bin/env bash
set -euo pipefail

# modules/git.sh
#
# PUBLIC:
#   git_setup_run
#   git_global_link_run
#
# ENV VARS USED:
#   DOTFILES_NONINTERACTIVE
#   SETUP_GIT
#
# SIDE EFFECTS:
#   Writes ~/.gitconfig.local
#   May configure global Git credential helper
#   Symlinks global git config and ignore files from DOTFILES_DIR

# Create or update ~/.gitconfig.local (interactive or via env)
create_gitconfig_local() {
  local target="$HOME/.gitconfig.local"
  local cur_name="" cur_email="" cur_editor=""

  if command -v git >/dev/null 2>&1; then
    cur_name="$(git config --global user.name || true)"
    cur_email="$(git config --global user.email || true)"
    cur_editor="$(git config --global core.editor || true)"
  fi

  if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
    : "${GIT_USER_NAME:?Set GIT_USER_NAME for non-interactive mode}"
    : "${GIT_USER_EMAIL:?Set GIT_USER_EMAIL for non-interactive mode}"
    GIT_EDITOR="${GIT_EDITOR:-${VISUAL:-${EDITOR:-nano}}}"
  else
    echo "→ Let's set your Git identity (saved to ~/.gitconfig.local)"
    read -rp "  Your name  [${cur_name:-Your Name}]: " GIT_USER_NAME || true
    read -rp "  Your email [${cur_email:-you@example.com}]: " GIT_USER_EMAIL || true
    read -rp "  Editor (vim/nano/code --wait) [${cur_editor:-${VISUAL:-${EDITOR:-nano}}}]: " GIT_EDITOR || true
    GIT_USER_NAME="${GIT_USER_NAME:-${cur_name:-Your Name}}"
    GIT_USER_EMAIL="${GIT_USER_EMAIL:-${cur_email:-you@example.com}}"
    GIT_EDITOR="${GIT_EDITOR:-${cur_editor:-${VISUAL:-${EDITOR:-nano}}}}"
  fi

  cat > "$target" <<EOF
[user]
    name = ${GIT_USER_NAME}
    email = ${GIT_USER_EMAIL}

[core]
    editor = ${GIT_EDITOR}

[init]
    defaultBranch = main

[pull]
    ff = only
EOF
  echo "  → wrote $target"

  # Sensible per-OS credential helper (if not already set)
  if command -v git >/dev/null 2>&1; then
    if ! git config --global --get credential.helper >/dev/null 2>&1; then
      case "$(uname -s)" in
        Darwin)  git config --global credential.helper osxkeychain ;;
        Linux)
          if command -v git-credential-libsecret >/dev/null 2>&1; then
            git config --global credential.helper libsecret
          else
            if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
              : # skip in CI unless user opts for store explicitly beforehand
            else
              read -rp "Use plaintext credential store (~/.git-credentials)? [y/N]: " ans || true
              [[ "$ans" =~ ^[Yy]$ ]] && git config --global credential.helper store
            fi
          fi
          ;;
      esac
    fi
  fi
}

# If DOTFILES_NONINTERACTIVE=1 then SETUP_GIT controls behavior:
#   SETUP_GIT=1  -> run setup
#   SETUP_GIT=0  -> skip setup
#   unset        -> skip by default in non-interactive
# In interactive mode, prompt only if git user.name or user.email are missing.
should_setup_git() {
  # If git isn't installed, nothing to do
  if ! command -v git >/dev/null 2>&1; then
    return 1
  fi

  local existing_name existing_email
  # Check for a configured identity at any level (local, global, system)
  existing_name=$(git config --get user.name || true)
  existing_email=$(git config --get user.email || true)

  if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
    # Non-interactive: allow explicit skip, otherwise default to running setup
    case "${SETUP_GIT:-}" in
      0) return 1 ;; # explicitly skip
      1) return 0 ;; # force setup
      *) ;;           # unset -> continue to detection below
    esac
  fi

  # If both name and email exist, print summary and skip
  if [[ -n "$existing_name" && -n "$existing_email" ]]; then
    echo "Found Git identity: name='$existing_name' email='$existing_email' — skipping setup."
    return 1
  fi

  # Interactive: if either name or email is missing, prompt to run setup
  if [[ "${DOTFILES_NONINTERACTIVE:-0}" != "1" ]]; then
    read -rp "No Git identity found. Create one now? [y/N]: " ans || true
    [[ "$ans" =~ ^[Yy]$ ]]
    return
  fi

  # Non-interactive and no identity -> run setup by default
  return 0
}

git_setup_run() {
  if should_setup_git; then
    create_gitconfig_local
  else
    echo "Skipping Git identity setup. To force it, set SETUP_GIT=1 or run create_gitconfig_local manually."
  fi
}

git_global_link_run() {
  echo "Linking global gitignore…"
  link "$DOTFILES_DIR/.gitignore_global" "$HOME/.gitignore_global"

  echo "Linking global Git config…"
  link "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
}


