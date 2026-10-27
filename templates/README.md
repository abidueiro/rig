# IDE Workflow Templates

Tmux-based development environment templates for the rig system.

## Templates

| Template | Purpose | Windows |
|----------|---------|---------|
| `ide-workflow.sh` | Generic IDE setup for any project | IDE, Docker (if compose), Git (if repo), Python, Tests |
| `django-dev.sh` | Django/Docker development | IDE, Compose, Docker, Git, Python Shell, Tests, Prod |
| `generic-dev.sh` | Minimal starter | Editor, Git, Shell |

## Quick Start

Launch from rig menu:
```
rig → [dev] 🪟 Tmux / Sesh → Launch workflow template
```

Or run directly from any project directory:
```bash
~/.config/rig/templates/ide-workflow.sh
```

## Windows

### 1. IDE (Always Created)

**Layout**: 75/25 vertical split
- **Top pane**: [Helix](https://helix-editor.com/) editor (or fallback)
- **Bottom pane**: opencode terminal

**Features**:
- Auto-detects editor: `helix` → `hx` → `micro` → `nano` → `vim` → `vi`
- Opens current directory in editor
- Mouse support enabled for drag-to-resize

### 2. LazyDocker (If `*.yml` or `docker-compose.*.yml` found)

Full Docker TUI for container management.

Fallback if lazydocker not installed: `watch -n2 docker ps`

### 3. Git (If `.git/` directory found)

Opens [gitui](https://github.com/extrawurst/gitui) or [lazygit](https://github.com/jesseduffield/lazygit).

Fallback: `git status`

### 4. Python (If Python/Django detected)

**Docker projects**:
```bash
docker-compose exec <service> python manage.py shell
```

**Direct execution**:
- Uses `ipython` if available, else `python3`
- Django: runs `manage.py shell`
- Generic: opens REPL

### 5. Tests (If `pytest.ini`, `tests/`, or `manage.py` found)

**Docker projects**:
```bash
docker-compose exec <service> pytest -v
# or
docker-compose exec <service> python manage.py test -v 2
```

**Direct execution**:
```bash
pytest
# or
python manage.py test
```

### 6. Prod (django-dev.sh only)

SSH to production host. Reads from `.env`:
```bash
PRODUCTION_HOST=myserver.com
PRODUCTION_USER=deploy  # optional, defaults to 'root'
```

## Editor Keybindings: Helix

| Key | Action |
|-----|--------|
| `Space` | Open command palette |
| `Space + f` | **Fuzzy find files** |
| `Space + b` | Switch buffers (tabs) |
| `Space + w` | Window/split management |
| `Space + /` | Global search in project |
| `Ctrl + c` | Cancel / close panel |
| `Ctrl + w` | Save file |
| `q` | Quit (in normal mode) |
| `i` | Insert mode |
| `Esc` | Normal mode |
| `x` | Select line |
| `d` | Delete selection |
| `y` | Yank (copy) |
| `p` | Paste |
| `u` | Undo |
| `Ctrl + r` | Redo |
| `g + d` | Go to definition |
| `g + r` | Go to references |
| `Ctrl + o` | Go back |
| `Ctrl + i` | Go forward |

Learn more: `Space` → "Help" or visit [docs.helix-editor.com](https://docs.helix-editor.com/)

## Tmux Keybindings

### Session Control

| Key | Action |
|-----|--------|
| `Ctrl + b` | **Prefix key** (hold before command) |
| `Ctrl + b` then `c` | Create new window |
| `Ctrl + b` then `n` | Next window |
| `Ctrl + b` then `p` | Previous window |
| `Ctrl + b` then `<number>` | Switch to window (0-9) |
| `Ctrl + b` then `w` | List windows (interactive) |
| `Ctrl + b` then `d` | Detach from session |
| `Ctrl + b` then `$` | Rename session |
| `Ctrl + b` then `s` | List sessions |

### Pane Management

| Key | Action |
|-----|--------|
| `Ctrl + b` then `"` | Split pane horizontally |
| `Ctrl + b` then `%` | Split pane vertically |
| `Ctrl + b` then `↑↓←→` | Navigate between panes |
| `Ctrl + b` then `z` | Zoom pane (toggle fullscreen) |
| `Ctrl + b` then `x` | Kill pane |
| `Ctrl + b` then `q` | Show pane numbers (then press number to jump) |
| `Ctrl + b` then `o` | Swap to next pane |
| `Ctrl + b` then `Space` | Cycle pane layouts |

### Pane Resizing

| Key | Action |
|-----|--------|
| `Ctrl + b` then `:` | Command mode (type resize commands) |
| `Ctrl + b` then `↑` | Resize pane up |
| `Ctrl + b` then `↓` | Resize pane down |
| `Ctrl + b` then `←` | Resize pane left |
| `Ctrl + b` then `→` | Resize pane right |
| **Mouse drag** | Drag pane borders to resize |

Resize command examples:
```
resize-pane -U 5    # Grow up by 5 lines
resize-pane -D 10   # Grow down by 10 lines
resize-pane -x 50%  # Set width to 50%
resize-pane -y 25   # Set height to 25 lines
```

### Copy Mode

| Key | Action |
|-----|--------|
| `Ctrl + b` then `[` | Enter copy mode |
| `Space` | Start selection |
| `Enter` | Copy selection |
| `Ctrl + b` then `]` | Paste buffer |
| `q` | Quit copy mode |
| `↑↓←→` or `PgUp/PgDn` | Navigate in copy mode |
| `/` | Search down |
| `?` | Search up |
| `n` | Next search result |
| `N` | Previous search result |

### Mouse Actions

| Action | Result |
|--------|--------|
| Drag pane border | Resize pane |
| Click pane | Focus pane |
| Click window name | Switch window |
| Double-click word | Select word |
| Triple-click line | Select line |
| Scroll wheel | Enter copy mode and scroll |

## Smart Detection

Templates automatically detect project type and create relevant windows:

```
Project/
├── docker-compose.yml        → Creates Docker window
├── .git/                     → Creates Git window
├── manage.py                 → Creates Python + Tests windows (Django)
├── pytest.ini               → Creates Tests window
├── requirements.txt         → Creates Python window
└── src/                     → Creates Python window
```

Docker service names detected: `web`, `django`, `app`, `api`, `backend`

## Tips

### Resize panes quickly

1. **Mouse**: Drag the border between panes
2. **Keyboard**: `Ctrl+b` then hold arrow keys
3. **Zoom**: `Ctrl+b` then `z` to fullscreen the current pane

### Switch between windows fast

- `Ctrl+b` `n` — next window
- `Ctrl+b` `p` — previous window  
- `Ctrl+b` `w` — interactive list with preview
- `Ctrl+b` `1` — jump to window 1 (IDE)
- `Ctrl+b` `2` — jump to window 2 (Docker)

### Re-attach to existing session

If you detach (`Ctrl+b` `d`), re-attach with:
```bash
tmux attach-session -t <project-name>
```

Or use the rig menu: `rig → Tmux / Sesh → Connect to session`

### Kill session when done

```bash
tmux kill-session -t <project-name>
```

Or via rig menu: `rig → Tmux / Sesh → Kill session`

### Custom keybindings

Add to your `~/.tmux.conf`:
```bash
# Reload config
bind r source-file ~/.tmux.conf

# Vim-style pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Quick resize
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Enable 256 colors
set -g default-terminal "screen-256color"
```

## Troubleshooting

**Editor not opening?**
- Templates fall back through: helix → micro → nano → vim → vi
- Install your preferred editor: `paru -S helix` or `brew install helix`

**Docker commands failing?**
- Ensure docker service is running: `sudo systemctl start docker`
- Check compose file exists: `ls docker-compose.yml`
- Verify service name in compose file matches detected name

**Git window not showing?**
- Must be inside a git repository: `git status`
- Run from project root, not a subdirectory

**Pane too small?**
- Resize with mouse drag or `Ctrl+b` then arrows
- Zoom with `Ctrl+b` `z`
- Detach and re-attach: `Ctrl+b` `d`, then re-attach

**Session already exists?**
- Templates auto-attach to existing sessions
- Kill it first: `tmux kill-session -t <name>`
- Or switch to it: `tmux switch-client -t <name>`

## Customization

Copy templates and modify:
```bash
cp ~/.config/rig/templates/ide-workflow.sh ~/.config/rig/templates/my-custom.sh
# Edit my-custom.sh, then it appears in rig template picker
```

Or create project-specific templates:
```bash
mkdir -p ~/my-project/.rig
cp ~/.config/rig/templates/ide-workflow.sh ~/my-project/.rig/custom.sh
# Edit, then run from that project — .rig/*.sh appears in picker
```

## See Also

- [Helix Editor](https://helix-editor.com/)
- [Tmux Cheat Sheet](https://tmuxcheatsheet.com/)
- [Lazydocker](https://github.com/jesseduffield/lazydocker)
- [GitUI](https://github.com/extrawurst/gitui)
- [Rig Main README](../README.md)
