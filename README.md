# Dotfiles — concise usage

This is my personal collection of **dotfiles and helper scripts**, used to quickly bootstrap my development machines for **Odoo development** with Cursor (MCP, agent skills) and VS Code-like editors.

It’s intentionally lightweight: a single bootstrap (`setup.sh`), a few small helpers in `bin/`, and some config templates in `templates/`.

---

## ⚡ Quick install

```zsh
git clone --recurse-submodules git@github.com:MohdAlmosawy/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x setup.sh
./setup.sh       # links dotfiles, installs ~/bin helpers, optional Cursor/MCP/skills/Odoo helpers
```

If you already cloned without submodules: `git submodule update --init vendor/skills`

---

## 🧩 Modular setup

Setup is split into focused modules under `modules/`. Use `DOTFILES_NONINTERACTIVE=1` for automation; flags like `SETUP_GIT`, `INSTALL_CURSOR`, `SETUP_MCP`, `SETUP_SKILLS`, and `INSTALL_ANTIGRAVITY` control optional steps.

Example (install everything non-interactively):

```zsh
DOTFILES_NONINTERACTIVE=1 SETUP_MCP=1 SETUP_SKILLS=1 INSTALL_CURSOR=1 ./setup.sh
```

## 🧠 Agent skills (optional)

Shared Cursor agent skills live in a forked submodule at `vendor/skills` ([MohdAlmosawy/skills](https://github.com/MohdAlmosawy/skills), based on [mattpocock/skills](https://github.com/mattpocock/skills)). Personal skills maintained by these dotfiles live in `skills/`.

**Setup** — during `./setup.sh`, answer yes when prompted, or run manually:

```zsh
./scripts/setup_skills.sh          # installs shared skills and links personal skills
./scripts/setup_skills.sh --personal-only  # links personal skills without Node.js
```

Shared skills are installed globally by the skills CLI. Personal skills are linked from `skills/<name>/` to `~/.cursor/skills/<name>/`; for example, `skills/commit-comment` becomes available as `/commit-comment`. Existing personal skill directories are backed up before being replaced. Restart Cursor after installing. Verify shared skills with `npx skills list -g`.

**Use in Cursor** — type `/` in chat to invoke user skills (e.g. `/grill-me`, `/to-prd`). Model-invoked skills (e.g. `tdd`, `diagnosing-bugs`) are picked up automatically when relevant. Run `/setup-matt-pocock-skills` once per project repo to configure issue tracker and domain docs.

**Customize** — edit `templates/skills.list` for shared skills, or add personal skills under `skills/<name>/SKILL.md`, then rerun `./scripts/setup_skills.sh`. Pull upstream changes with `sync-skills-upstream`.

---

## ⚙️ MCP and templates

`scripts/setup_mcp.sh` helps generate `~/.config/Code/User/mcp.json` from `templates/mcp.json.template` and installs `mcp-odoo` into your virtualenv.
Run it if you want the user-level VS Code MCP config for Odoo.

---


## 🧰 update-manifest

A small CLI helper installed by `./setup.sh` into `~/bin` that updates and normalizes Odoo `__manifest__.py` files with your preferred defaults (author, license, version, application flags, etc.).

Run `update-manifest --help` for available options.

---

## 🚀 create-odoo-workspace

Scaffolds VS Code-like workspace files for Odoo modules. Automatically discovers dependencies from `__manifest__.py`, configures Python paths, debug settings, and Odoo Language Server integration.

Usage: `create-odoo-workspace.sh <path-to-module> [odoo-version|config-path]`

---

## 🗒️ Notes & tips

- Workspaces and `.vscode` settings are **VS Code-like**. Cursor-specific pieces are `~/.cursor/mcp.json` and agent skills under `~/.agents/skills/`.
- Add `~/.cursor/mcp.json` and any local `.vscode/launch.json` to your personal `.gitignore` to avoid committing secrets.
- This repo stays **minimal by design** — no shells, themes, or frameworks; just portable scripts I can trust anywhere.

---

