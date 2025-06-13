# Dotfiles Setup

## Steps

1. **Clone your dotfiles wherever you like (example: `~/dotfiles`):**
   ```sh
   git clone git@github.com:MohdAlmosawy/dotfiles.git ~/dotfiles
   ```

2. **Enter the directory:**
   ```sh
   cd ~/dotfiles
   ```

3. **Make the setup script executable (only needed once):**
   ```sh
   chmod +x setup.sh
   ```

4. **Run the setup script:**
   ```sh
   ./setup.sh
   ```

5. **(Optional) Auto-install Cursor**  
   By default, running `./setup.sh` will automatically download Cursor for you if needed. 
   You only need to use the `export CURSOR_APPIMAGE_URL=...` line below if you want to override the default download URL (for example, to use a different version or a custom source):

   ```bash
   export CURSOR_APPIMAGE_URL="https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
   ./setup.sh
   ```

6. **Use `cursor` from anywhere**

   ```bash
   cursor /path/to/your/project
   ```

   Your shell prompt will return immediately, and Cursor will open that folder.

## MCP Server Configuration (Cursor)

This repo uses a template for Cursor's MCP server config: `templates/mcp.json.template`.

- **Sensitive keys and passwords are NOT stored in git.**
- The real config (`~/.cursor/mcp.json`) is created from the template during setup.
- **After running `./setup.sh`, you must edit `~/.cursor/mcp.json` and fill in your real API keys and passwords.**
- Never commit your real `mcp.json` file to git.

If you ever need to reset your MCP config, just copy the template again:

```sh
cp ~/dotfiles/templates/mcp.json.template ~/.cursor/mcp.json
# Then edit ~/.cursor/mcp.json to add your secrets
```
