# Dotfiles — concise usage

This is my personal collection of **dotfiles and helper scripts**, used to quickly bootstrap my development machines and work with **Cursor’s MCP (multi-code-project)** setup for Odoo development.

It’s intentionally lightweight: a single bootstrap (`setup.sh`), a few small helpers in `bin/`, and some config templates in `templates/`.

> The only special piece here is `create-odoo-workspace.sh` — everything else is standard dotfile linking and MCP templating.

---

## ⚡ Quick install

```zsh
git clone git@github.com:MohdAlmosawy/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x setup.sh
./setup.sh       # links dotfiles, installs ~/bin helpers, optional Cursor/Antigravity/MCP/Odoo helpers
```

---

## 🧩 Modular setup

Setup is split into focused modules under `modules/`. Use `DOTFILES_NONINTERACTIVE=1` for automation; other flags like `SETUP_GIT`, `INSTALL_CURSOR`, `INSTALL_ANTIGRAVITY` control optional steps.

## 🧠 Agent skills

Forked from [mattpocock/skills](https://github.com/mattpocock/skills) as a git submodule at `vendor/skills` ([MohdAlmosawy/skills](https://github.com/MohdAlmosawy/skills)).

```zsh
# Fresh clone (include submodule)
git clone --recurse-submodules git@github.com:MohdAlmosawy/dotfiles.git ~/dotfiles

# Existing clone
git submodule update --init vendor/skills
./scripts/setup_skills.sh
```

`setup.sh` can install skills into Cursor interactively, or non-interactively with `SETUP_SKILLS=1`.

Edit `templates/skills.list` to change which skills are installed. Merge upstream changes with `sync-skills-upstream`.

---

## ⚙️ MCP and templates

`scripts/setup_mcp.sh` helps generate `~/.cursor/mcp.json` from `templates/mcp.json.template` and installs `mcp-odoo` into your virtualenv.
Run it only if you use Cursor’s MCP feature — otherwise you can ignore this part.

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

- Workspaces and `.vscode` settings are **VS Code-like**.  
  Only `mcp.json` is Cursor-specific.
- Add `~/.cursor/mcp.json` and any local `.vscode/launch.json` to your personal `.gitignore` to avoid committing secrets.
- This repo stays **minimal by design** — no shells, themes, or frameworks; just portable scripts I can trust anywhere.
- The only custom helper worth noting is `create-odoo-workspace.sh`, which scaffolds Odoo workspaces for VS Code-like editors.

---

