#!/usr/bin/env bash
# Install agent skills from the dotfiles vendor/skills submodule into Cursor.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_REPO="$DOTFILES_DIR/vendor/skills"
SKILLS_LIST_FILE="$DOTFILES_DIR/templates/skills.list"

usage() {
  cat <<'EOF'
Usage: setup_skills.sh

Sync vendor/skills (git submodule) and install selected skills into Cursor.

Environment:
  DOTFILES_SKILLS       Space-separated skill names (overrides templates/skills.list)
  DOTFILES_SKILLS_AGENT Target agent for skills CLI (default: cursor)
  DOTFILES_SKILLS_GLOBAL Install globally (default: 1). Set to 0 for project-level.

Examples:
  ./scripts/setup_skills.sh
  DOTFILES_SKILLS="tdd grill-with-docs" ./scripts/setup_skills.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ensure_git_submodule() {
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    echo "ERROR: $DOTFILES_DIR is not a git repository."
    exit 1
  fi

  echo "→ Syncing vendor/skills submodule…"
  git -C "$DOTFILES_DIR" submodule sync --recursive vendor/skills
  git -C "$DOTFILES_DIR" submodule update --init --recursive vendor/skills
}

ensure_npx() {
  if ! command -v npx >/dev/null 2>&1; then
    echo "ERROR: npx is required to install skills. Install Node.js first."
    exit 1
  fi
}

read_skill_list() {
  local -a skills=()

  if [[ -n "${DOTFILES_SKILLS:-}" ]]; then
    # shellcheck disable=SC2206
    skills=($DOTFILES_SKILLS)
  elif [[ -f "$SKILLS_LIST_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%%#*}"
      line="$(echo "$line" | xargs)"
      [[ -n "$line" ]] && skills+=("$line")
    done < "$SKILLS_LIST_FILE"
  else
    echo "ERROR: No skills list found at $SKILLS_LIST_FILE"
    exit 1
  fi

  if [[ ${#skills[@]} -eq 0 ]]; then
    echo "ERROR: Skills list is empty."
    exit 1
  fi

  printf '%s\n' "${skills[@]}"
}

install_skills() {
  local agent="${DOTFILES_SKILLS_AGENT:-cursor}"
  local global_flag=(-g)
  local -a skills
  local -a skill_args=()
  local skill

  if [[ "${DOTFILES_SKILLS_GLOBAL:-1}" == "0" ]]; then
    global_flag=()
  fi

  if [[ ! -d "$SKILLS_REPO/skills" ]]; then
    echo "ERROR: $SKILLS_REPO does not look like a skills repository."
    exit 1
  fi

  mapfile -t skills < <(read_skill_list)

  for skill in "${skills[@]}"; do
    skill_args+=(-s "$skill")
  done

  echo "→ Installing ${#skills[@]} skill(s) for agent '$agent' from $SKILLS_REPO"
  npx --yes skills@latest add "$SKILLS_REPO" \
    "${global_flag[@]}" \
    -a "$agent" \
    "${skill_args[@]}" \
    -y
}

ensure_git_submodule
ensure_npx
install_skills

echo "✔ Agent skills installed."
