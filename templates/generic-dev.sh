#!/usr/bin/env bash
# =============================================================================
# rig template: generic-dev
# Minimal development session: editor, git (if repo), terminal.
# Use as a starting point for custom templates.
#
# Windows:
#   1. IDE      — top 75%: helix editor (or fallback) | bottom 25%: terminal
#   2. Git      — gitui (only if git repo found)
#   3. Shell    — free terminal
#
# Copy to ~/.config/rig/templates/my-project.sh and customise.
# Or place as .rig/template.sh inside your project for project-specific setup.
# =============================================================================

PROJECT_DIR="${1:-$PWD}"
PROJECT_NAME="${2:-$(basename "$PROJECT_DIR")}"
SESSION="$PROJECT_NAME"

# ── Guard: tmux ─────────────────────────────────────────────────────────────
if ! command -v tmux &>/dev/null; then
  echo "  ✗ tmux is not installed." >&2; exit 1
fi

# ── Guard: project dir must exist ──────────────────────────────────────────
if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "  ✗ Project directory not found: $PROJECT_DIR" >&2; exit 1
fi

cd "$PROJECT_DIR" || exit 1

# ── Already exists: just attach ──────────────────────────────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "  Session '$SESSION' already exists — connecting..."
  [[ -n "$TMUX" ]] && tmux switch-client -t "$SESSION" \
    || tmux attach-session -t "$SESSION"
  exit 0
fi

# ── Detect git repo ─────────────────────────────────────────────────────────
HAS_GIT=false
git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null 2>&1 && HAS_GIT=true

# ── Detect editor ─────────────────────────────────────────────────────────
EDITOR_CMD="helix"
if ! command -v helix &>/dev/null && ! command -v hx &>/dev/null; then
  if command -v micro &>/dev/null; then
    EDITOR_CMD="micro"
  elif command -v nano &>/dev/null; then
    EDITOR_CMD="nano"
  elif command -v vim &>/dev/null; then
    EDITOR_CMD="vim"
  else
    EDITOR_CMD="vi"
  fi
else
  command -v hx &>/dev/null && EDITOR_CMD="hx"
fi

# ── Summary before launching ─────────────────────────────────────────────────
echo ""
echo "  rig generic-dev template"
echo "  ─────────────────────────────────────"
echo "  Session:    $SESSION"
echo "  Dir:        $PROJECT_DIR"
echo "  Editor:     $EDITOR_CMD (Space+f for fuzzy find)"
echo "  Git repo:   ${HAS_GIT}"
echo ""

# ── Create session ───────────────────────────────────────────────────────────
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -n "IDE"

# Enable mouse support for easy resizing
tmux set-option -t "$SESSION" -g mouse on

# ── Window 1: IDE (75/25 split) ─────────────────────────────────────────────
# Top pane (75%): Editor
tmux send-keys -t "${SESSION}:IDE" "$EDITOR_CMD ." Enter

# Bottom pane (25%): Terminal
tmux split-window -v -t "${SESSION}:IDE" -c "$PROJECT_DIR" -p 25
tmux send-keys -t "${SESSION}:IDE" "echo '  Free terminal — run any commands here'" Enter

# Focus top pane (editor)
tmux select-pane -t "${SESSION}:IDE" -U 2>/dev/null || tmux select-pane -t "${SESSION}:IDE.0"

# ── Window 2: Git (only if git repo) ───────────────────────────────────────
if [[ "$HAS_GIT" == true ]]; then
  tmux new-window -t "$SESSION" -n "Git" -c "$PROJECT_DIR"
  if command -v gitui &>/dev/null; then
    tmux send-keys -t "${SESSION}:Git" "gitui" Enter
  elif command -v lazygit &>/dev/null; then
    tmux send-keys -t "${SESSION}:Git" "lazygit" Enter
  else
    tmux send-keys -t "${SESSION}:Git" \
      "echo '  ℹ gitui/lazygit not installed — showing git status' && git status" Enter
  fi
fi

# ── Window 3: Shell (free terminal) ─────────────────────────────────────────
tmux new-window -t "$SESSION" -n "Shell" -c "$PROJECT_DIR"

# ── Focus IDE, attach ────────────────────────────────────────────────────────
tmux select-window -t "${SESSION}:IDE"
[[ -n "$TMUX" ]] && tmux switch-client -t "$SESSION" \
  || tmux attach-session -t "$SESSION"
