# rig — Terminal Resource Interactive Guide

A TUI launcher for the terminal. Combines [television (tv)](https://github.com/alexpasmantier/television), [fzf](https://github.com/junegunn/fzf) and [gum](https://github.com/charmbracelet/gum) into a unified fuzzy menu with categories, previews and contextual actions.

```
rig — type to filter · [nav] [dev] [sys] [net] [tool]
> search...
  [nav]   📁  Browse files
  [nav]   📂  Browse directories (cd)
  [nav]   🔍  Search file contents
  [dev]   🐋  Docker
  [dev]   🐍  Django (current project)
  ...
```

---

## Features

### [nav] Navigation
| Option | Description |
|--------|-------------|
| Browse files | `fd` + preview with `bat`. `ctrl-o` opens in Zed, `ctrl-t` opens Ghostty in the file directory |
| Browse directories (cd) | `fd` with `ls` preview. Supports current dir, home or zoxide history. **cd works in the parent shell** |
| Search file contents | `rg` + `fzf` with file preview and highlighted line |

### [dev] Development
| Option | Description |
|--------|-------------|
| Docker | lazydocker, containers (inspect/logs/shell/restart/stop), images, networks, volumes, docker-compose |
| Django | Search django log (path configured at install), follow live, filter errors/warnings |
| Python venvs / uv | List, activate and create venvs (supports uv and python -m venv) |
| Git | gitui, log with diff, branches + checkout, stash, modified files |
| Tmux / Sesh | Connect/create/kill sessions via sesh. Launch workflow templates that spin up a full tmux session with pre-configured windows |

### [sys] System
| Option | Description |
|--------|-------------|
| System logs | journalctl, boot log, dmesg + custom log files configured at install. Search or follow live |
| Systemd services | List (all/active/failed), start/stop/restart/enable/disable with status preview |
| Processes | ps aux with management: SIGTERM/SIGKILL/SIGINT, renice, pstree, lsof |
| Backup (rsync) | rsync with excludes file. Pick destination from saved hosts, pre-configured list, or ad-hoc SSH host. Dry run, live run, log viewer |

### [net] Network
| Option | Description |
|--------|-------------|
| Ports / Connections | `ss -tulpn` with preview of the listening process |
| SSH → Connect | Unified host picker: saved rig hosts + `~/.ssh/config`. Connect or open in tmux |
| SSH → Mount filesystem | sshfs — pick host, set remote dir, local mount point auto-created |
| SSH → SOCKS proxy | Dynamic proxy on a local port. Configure browser: `SOCKS5 localhost:<port>` |
| SSH → Port forward | Local→Remote or Remote→Local tunnel with configurable ports |
| SSH → Run remote app | Launch a remote GUI app locally via X11 forwarding |
| SSH → Manage saved hosts | Add / edit / delete hosts in `~/.config/rig/hosts.conf`. fzf picker with preview |
| WireGuard | Launches `wgs` or falls back to `sudo wg show` |

### [tool] Tools
| Option | Description |
|--------|-------------|
| Cheat sheets | cht.sh fuzzy search — inline preview, opens in `less` |
| Environment variables | `tv env` |
| Weather | wttr.in — cities configured during install, plus manual input at any time |

---

## Dependencies

### Core (required)
| Tool | Purpose | Install |
|------|---------|---------|
| `gum` | TUI menus, inputs, confirmations | `paru -S gum` / `brew install gum` |
| `fzf` | Fuzzy finder with preview | `paru -S fzf` / `apt install fzf` |
| `bat` | File preview with syntax highlighting | `paru -S bat` / `apt install bat` |

### Highly recommended
| Tool | Purpose |
|------|---------|
| `tv` (television) | ssh-hosts, git-log, git-branches, docker-all, env vars channels |
| `fd` | Fast file/dir search (alternative to find) |
| `rg` (ripgrep) | Fast recursive content search |

### Optional (enable specific features)
| Tool | Feature |
|------|---------|
| `zoxide` | Directory history navigation |
| `lazydocker` | Full Docker TUI |
| `gitui` | Full Git TUI |
| `sesh` | Tmux session manager (required for Tmux section) |
| `uv` | Faster venv creation |
| `lsof` | Files opened by process |
| `pstree` | Process tree view |
| `ss` | Ports and connections |
| `curl` | Weather (wttr.in) + cheat sheets (cht.sh) |
| `tmux` | Open SSH in a new window |
| `sshfs` | Mount remote filesystems |
| `rsync` | Backup section |
| `wgs` | WireGuard helper |
| `sshub` | SSH host manager integration (hosts, tunnels, sftp) |

### Television cable channels
`.toml` files that go in `~/.config/television/cable/`:
- `files-open.toml` — files with Zed / Ghostty actions
- `docker-all.toml` — containers with contextual actions
- `ssh-hosts.toml` — SSH hosts with config preview
- `git-log.toml` — commits with diff preview
- `git-branches.toml` — branches with checkout
- `git-stash.toml` — stash with diff preview
- `git-modified.toml` — modified files with diff preview

---

## Installation

### Option A — Interactive installer (recommended)

```bash
git clone https://github.com/your-user/rig   # or copy the files
cd rig
chmod +x install.sh
./install.sh
```

The installer is a step-by-step wizard powered by `gum`. For each section it shows which tools are available (✓/✗) and asks whether to enable it. Sections with missing tools default to disabled but can still be turned on if you plan to install them later.

The wizard also collects:

| Prompt | What it configures |
|--------|--------------------|
| Weather cities | Quick-select cities in the weather menu (e.g. London, Tokyo). Leave empty to always prompt manually. |
| Log files | Custom log files to add to System logs (label + path pairs, e.g. `nginx error` → `/var/log/nginx/error.log`). |
| Django log path | Path to the Django log file relative to `$PWD` (default: `logs/django.log`). |
| SSH config path | Path to the SSH config file (default: `~/.ssh/config`). |
| Backup source | Directory to back up (default: `$HOME`). |
| Backup destinations | One or more rsync destinations. SSH host picker available if `~/.ssh/config` or saved rig hosts exist. |
| Excludes file | Generate `~/rsync_exclude.txt` with sensible defaults, use an existing file, or skip. |

The installer copies `rsync_exclude.txt` from the rig directory if present, otherwise generates it inline. It covers caches, browser data, build artifacts, language toolchains (Rust, Go, Python, Node, Java) and heavyweight directories (node_modules, .cargo, .venv, Steam, etc.).

Everything is saved to `~/.config/rig/rig.conf`. Run `./install.sh` again at any time to reconfigure.

### Option B — Manual with GNU Stow (dotfiles)

Expected structure inside the dotfiles repository:

```
dotfiles/
├── zsh/
│   ├── .zshrc
│   └── .config/
│       └── zsh/
│           └── rig.zsh              ← zsh function
├── television/
│   └── .config/
│       └── television/
│           └── cable/
│               ├── files-open.toml
│               ├── docker-all.toml
│               ├── ssh-hosts.toml
│               ├── git-log.toml
│               ├── git-branches.toml
│               ├── git-stash.toml
│               └── git-modified.toml
└── rig/
    └── .config/
        └── rig/
            └── rig.conf             ← generated by install.sh
```

```bash
cd ~/dotfiles
stow zsh
stow television
stow rig
```

### Option C — Server (bash, no zsh or stow)

```bash
cp rig.sh ~/.local/bin/rig
chmod +x ~/.local/bin/rig
./install.sh   # generates rig.conf based on available tools
```

For **cd to work** in bash, add one of these to `~/.bashrc`:

```bash
# Option 1: source directly
source ~/.local/bin/rig

# Option 2: alias
alias rig='. ~/.local/bin/rig'
```

---

## Configuration

All configuration lives in `~/.config/rig/rig.conf`, generated by `install.sh`. You can also edit it manually at any time.

### Enable / disable sections

```bash
RIG_DEV_DJANGO=false
RIG_TOOL_WEATHER=false
RIG_NET_WG=false
```

### Paths

```bash
# Django log path (relative to $PWD when rig is launched)
RIG_DJANGO_LOG="app/logs/django.log"

# SSH config file
RIG_SSH_CONFIG="$HOME/.ssh/work_config"
```

### Weather cities

Pipe-separated list of cities shown as quick-select options. Leave empty to always prompt for manual input.

```bash
RIG_WEATHER_CITIES="London|Tokyo|Berlin"
```

### Custom log files

Pipe-separated list of `label:path` pairs added to the System logs menu. sudo is applied automatically for paths under `/var/log`.

```bash
RIG_LOG_FILES="nginx error:/var/log/nginx/error.log|nginx access:/var/log/nginx/access.log|app:/var/log/myapp/app.log"
```

### SSH host manager (sshub)

If [`sshub`](https://crates.io/crates/sshub) is installed, rig can use it as the backend for SSH host selection and management. When enabled, the SSH picker, saved-host management and connection actions go through `sshub` instead of `~/.ssh/config` or `~/.config/rig/hosts.conf`.

```bash
RIG_USE_SSHUB=true   # default when sshub is available
```

Set it to `false` to fall back to the native host file / `~/.ssh/config` picker.

When `RIG_USE_SSHUB=true`:
- **SSH → Connect** runs `sshub host connect <name>`.
- **SSH → Manage saved hosts** opens the `sshub` TUI.
- **SSH → sshfs / SOCKS / tunnel / remote app** resolve the host with `sshub host show` and fall back to plain `ssh`.
- The backup destination picker can also select an sshub host.

`sshub` is installed separately, for example with cargo:

```bash
cargo install sshub
```

### Saved hosts

rig maintains its own hosts file independent of `~/.ssh/config`:

```
~/.config/rig/hosts.conf
```

Format — one host per line:
```
# name|user|host|port|description
homelab|alf|192.168.1.10|22|Proxmox main node
vps-fra|root|fra.example.com|22|Frankfurt VPS
nas|alf|192.168.1.50|2222|NAS (custom port)
```

Manage from **SSH → Manage saved hosts**: fzf list with preview, Add / Edit / Delete. All SSH submenus (Connect, sshfs, SOCKS, tunnel, remote app) and the Backup destination picker show both saved rig hosts and `~/.ssh/config` entries combined.

```bash
# Custom path if needed
RIG_HOSTS_FILE="$HOME/.config/rig/hosts.conf"
```

### Backup

```bash
# Source directory
RIG_BACKUP_SOURCE="/home/user"

# Pre-configured destinations (pipe-separated)
# At runtime you can also pick any saved rig host on the fly
RIG_BACKUP_DESTINATIONS="nas:/backup|/mnt/external"

# Excludes file (default: ~/rsync_exclude.txt)
RIG_BACKUP_EXCLUDES_FILE="$HOME/rsync_exclude.txt"
```

The excludes file (`~/rsync_exclude.txt`) is a plain text file with one pattern per line, passed to rsync via `--exclude-from`. The default generated by the installer covers:

- System caches, Trash, browser caches
- Flatpak, containers, Docker
- Gaming (Steam)
- Python tooling (`.venv`, `__pycache__`, `.pyenv`, `.pytest_cache`)
- Node/JS (`node_modules`, `.npm`, `.bun`)
- Rust (`.cargo`, `.rustup`)
- Go, Java, Android (`.m2`, `.gradle`, `.android`)
- Zsh compiled files (`.zwc`, `.zcompdump*`)

Edit `~/rsync_exclude.txt` at any time to add or remove patterns.

### Reconfigure interactively

```bash
./install.sh   # reruns the full wizard and overwrites rig.conf
```

---

## Usage

```
rig              # open the menu
Ctrl+Space       # open from any prompt (zsh keybinding)
```

In the main menu, **type to filter**:
- `nav` → navigation options only
- `dev` → Docker, Django, Python, Git
- `sys` → logs, systemd, processes
- `net` → ports, SSH, WireGuard
- `tool` → cheat sheets, env vars, weather
- `docker` → goes straight to Docker
- `git` → goes straight to Git

---

## Ctrl+Space keybinding (zsh)

Included in `rig.zsh`:

```zsh
function _rig_widget() {
  rig
  zle reset-prompt
}
zle -N _rig_widget
bindkey '^ ' _rig_widget
```

If Ctrl+Space is already taken (e.g. tmux prefix), change it:

```zsh
bindkey '^o' _rig_widget    # Ctrl+O
bindkey '^[r' _rig_widget   # Alt+R
```

---

## Workflow Templates (Tmux / Sesh)

Templates are shell scripts that create a full tmux session with pre-configured windows. Launch them from **rig → Tmux / Sesh → Launch workflow template**.

### Template lookup order

1. **Local** — `.rig/*.sh` inside the current project directory (project-specific)
2. **Global** — `~/.config/rig/templates/*.sh` (shared across projects)

Local templates take priority. If both exist they are shown together in the picker.

### Included templates

**`django-dev`** — full Django/Docker development session:

| Window | Name | Content |
|--------|------|---------|
| 1 | `compose` | Top: `docker-compose up` · Bottom: filtered logs for `django` + `celery` |
| 2 | `docker` | `lazydocker` |
| 3 | `git` | `gitui` |
| 4 | `code` | `opencode` |
| 5 | `prod` | SSH to production host (reads `PRODUCTION_HOST` from `.env`, falls back to rig host picker) |

If multiple compose files are found (`docker-compose.development.yml`, `docker-compose.yml`, `compose.yml`, etc.) the template asks which one to use.

**`generic-dev`** — minimal starter: editor, git, free shell. Copy and customise.

### Writing your own template

```bash
#!/usr/bin/env bash
# Args: $1 = project dir, $2 = project name (used as session name)

PROJECT_DIR="${1:-$PWD}"
PROJECT_NAME="${2:-$(basename "$PROJECT_DIR")}"
SESSION="$PROJECT_NAME"

cd "$PROJECT_DIR" || exit 1

# Skip if session already exists
tmux has-session -t "$SESSION" 2>/dev/null && {
  [[ -n "$TMUX" ]] && tmux switch-client -t "$SESSION" \
    || tmux attach-session -t "$SESSION"
  exit 0
}

tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -n "main"
tmux send-keys -t "${SESSION}:main" "your-command-here" Enter

tmux new-window -t "$SESSION" -n "shell" -c "$PROJECT_DIR"

[[ -n "$TMUX" ]] && tmux switch-client -t "$SESSION" \
  || tmux attach-session -t "$SESSION"
```

Place it in `~/.config/rig/templates/my-template.sh` or `.rig/my-template.sh` inside your project. It appears automatically in the picker.

### Production host detection

The `django-dev` template looks for these variables in `.env` (in order):

```bash
PRODUCTION_HOST=myserver.example.com
SSH_HOST=myserver.example.com
DEPLOY_HOST=myserver.example.com
REMOTE_HOST=myserver.example.com
```

If none are found, the prod window shows a prompt and you can connect manually or use rig's SSH picker.

---

## Repository structure

```
rig/
├── rig.zsh              # zsh version (function, cd works in parent shell)
├── rig.sh               # bash version (for servers)
├── install.sh           # installer — interactive wizard
├── rsync_exclude.txt    # default rsync excludes
├── README.md
├── templates/           # workflow templates (copied to ~/.config/rig/templates/)
│   ├── django-dev.sh    # Django + Docker full dev session
│   └── generic-dev.sh   # minimal starter template
└── cable/               # television cable channels
    ├── files-open.toml
    ├── docker-all.toml
    ├── ssh-hosts.toml
    ├── git-log.toml
    ├── git-branches.toml
    ├── git-stash.toml
    └── git-modified.toml
```
