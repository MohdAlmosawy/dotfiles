#!/usr/bin/env bash
set -euo pipefail

# modules/skills.sh
#
# PUBLIC:
#   skills_setup_run
#
# ENV VARS USED:
#   DOTFILES_NONINTERACTIVE
#   SETUP_SKILLS
#   DOTFILES_DIR
#
# SIDE EFFECTS:
#   May install vendored skills and link personal skills into Cursor

skills_setup_run() {
  if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
    if [[ "${SETUP_SKILLS:-0}" == "1" ]]; then
      "$DOTFILES_DIR/scripts/setup_skills.sh"
    else
      echo "Skipping agent skills setup (non-interactive)."
    fi
    return
  fi

  read -rp "Set up agent skills (vendored + personal → Cursor)? [y/N]: " setup_skills || true
  if [[ "$setup_skills" =~ ^[Yy]$ ]]; then
    "$DOTFILES_DIR/scripts/setup_skills.sh"
  else
    echo "Skipping agent skills setup. Run scripts/setup_skills.sh later."
  fi
}
