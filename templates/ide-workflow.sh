#!/usr/bin/env bash
# =============================================================================
# rig template: ide-workflow
# IDE-focused development workflow with Helix editor, conditional tools.
#
# Windows:
#   1. IDE      — top 75%: helix editor | bottom 25%: opencode
#   2. Docker   — lazydocker (only if *.yml or docker-compose.*.yml found)
#   3. Git      — gitui (only if git repo found)
#   4. Python   — python REPL or django shell (if manage.py)
#   5. Tests    — test runner (if pytest.ini, tests/, or manage.py)
#
# Run from your project directory, or pass it as argument.
# =============================================================================

PROJECT_DIR="${1:-$PWD}"
PROJECT_NAME="${2:-$(basename "$PROJECT_DIR")}"
SESSION="$PROJECT_NAME"

# ── Guard: tmux ───────────────────────────────────────────────────────────────
if ! command -v tmux &>/dev/null; then
  echo "  ✗ tmux is not installed." >&2; exit 1
fi

# ── Guard: project dir must exist ─────────────────────────────────────────────
if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "  ✗ Project directory not found: $PROJECT_DIR" >&2; exit 1
fi

cd "$PROJECT_DIR" || exit 1

# ── Already exists: just attach ─────────────────────────────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "  Session '$SESSION' already exists — connecting..."
  [[ -n "$TMUX" ]] && tmux switch-client -t "$SESSION" \
    || tmux attach-session -t "$SESSION"
  exit 0
fi

# ── Detect compose file(s) ───────────────────────────────────────────────────
COMPOSE_FILES=()
for candidate in \
  "docker-compose.development.yml" \
  "docker-compose.dev.yml" \
  "docker-compose.local.yml" \
  "docker-compose.yml" \
  "compose.yml"; do
  [[ -f "$PROJECT_DIR/$candidate" ]] && COMPOSE_FILES+=("$candidate")
done

# Also check for any .yml files
while IFS= read -r -d '' yml_file; do
  [[ " ${COMPOSE_FILES[*]} " != *" $yml_file "* ]] && COMPOSE_FILES+=("$yml_file")
done < <(find "$PROJECT_DIR" -maxdepth 1 -name "*.yml" -print0 2>/dev/null)

COMPOSE_FILE=""
HAS_COMPOSE=false
if [[ ${#COMPOSE_FILES[@]} -gt 0 ]]; then
  COMPOSE_FILE="${COMPOSE_FILES[0]}"
  HAS_COMPOSE=true
fi

# ── Detect docker-compose command (v1 vs v2) ──────────────────────────────────
DC_CMD="docker-compose"
if command -v docker &>/dev/null && docker compose version &>/dev/null 2>&1; then
  DC_CMD="docker compose"
fi

# ── Detect git repo ─────────────────────────────────────────────────────────
HAS_GIT=false
git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null 2>&1 && HAS_GIT=true

# ── Detect Python/Django project ─────────────────────────────────────────────
HAS_PYTHON=false
HAS_DJANGO=false
HAS_TESTS=false
PYTHON_CMD="python3"
[[ -f "$PROJECT_DIR/manage.py" ]] && HAS_DJANGO=true
[[ -f "$PROJECT_DIR/pyproject.toml" || -f "$PROJECT_DIR/requirements.txt" || -f "$PROJECT_DIR/setup.py" || -d "$PROJECT_DIR/src" ]] && HAS_PYTHON=true
[[ -f "$PROJECT_DIR/pytest.ini" || -d "$PROJECT_DIR/tests" || -d "$PROJECT_DIR/test" ]] && HAS_TESTS=true

# Detect docker service name for web/django
DOCKER_SERVICE=""
if [[ "$HAS_COMPOSE" == true && -f "$COMPOSE_FILE" ]]; then
  # Look for common service names
  for svc in web django app api backend; do
    if grep -qE "^\s+${svc}:" "$COMPOSE_FILE" 2>/dev/null; then
      DOCKER_SERVICE="$svc"
      break
    fi
  done
fi

# ── Detect editor ────────────────────────────────────────────────────────────
EDITOR_CMD="helix"
if ! command -v helix &>/dev/null && ! command -v hx &>/dev/null; then
  # Fallback chain
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
  # Use hx if helix binary is named hx
  command -v hx &>/dev/null && EDITOR_CMD="hx"
fi

# ── Summary before launching ────────────────────────────────────────────────
echo ""
echo "  rig ide-workflow template"
echo "  ─────────────────────────────────────"
echo "  Session:    $SESSION"
echo "  Dir:        $PROJECT_DIR"
echo "  Editor:     $EDITOR_CMD (Space+f for fuzzy find)"
echo "  Compose:    ${COMPOSE_FILE:-none}"
echo "  Git repo:   ${HAS_GIT}"
echo "  Python:     ${HAS_PYTHON}"
echo "  Django:     ${HAS_DJANGO}"
echo "  Tests:      ${HAS_TESTS}"
echo ""

# ── Create session ────────────────────────────────────────────────────────────
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -n "IDE"

# Enable mouse support for easy resizing
tmux set-option -t "$SESSION" -g mouse on

# ── Window 1: IDE (75/25 split) ───────────────────────────────────────────────
# Top pane (75%): Editor
tmux send-keys -t "${SESSION}:IDE" "$EDITOR_CMD ." Enter

# Bottom pane (25%): opencode
tmux split-window -v -t "${SESSION}:IDE" -c "$PROJECT_DIR" -p 25
if command -v opencode &>/dev/null; then
  tmux send-keys -t "${SESSION}:IDE" "opencode" Enter
else
  tmux send-keys -t "${SESSION}:IDE" "echo '  ℹ opencode not installed — this is a free terminal'" Enter
fi

# Focus top pane (editor)
tmux select-pane -t "${SESSION}:IDE" -U 2>/dev/null || tmux select-pane -t "${SESSION}:IDE.0"

# ── Window 2: LazyDocker (only if compose files found) ──────────────────────
if [[ "$HAS_COMPOSE" == true ]]; then
  tmux new-window -t "$SESSION" -n "LazyDocker" -c "$PROJECT_DIR"
  if command -v lazydocker &>/dev/null; then
    tmux send-keys -t "${SESSION}:LazyDocker" "lazydocker" Enter
  else
    tmux send-keys -t "${SESSION}:LazyDocker" \
      "echo '  ℹ lazydocker not installed — showing docker ps' && watch -n2 docker ps" Enter
  fi
fi

# ── Window 3: Gitui (only if git repo) ───────────────────────────────────────
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

# ── Window 4: Python/Django Shell ────────────────────────────────────────────
if [[ "$HAS_PYTHON" == true || "$HAS_DJANGO" == true ]]; then
  tmux new-window -t "$SESSION" -n "Python" -c "$PROJECT_DIR"
  
  if [[ "$HAS_COMPOSE" == true && -n "$DOCKER_SERVICE" ]]; then
    # Docker-based Python/Django
    if [[ "$HAS_DJANGO" == true ]]; then
      tmux send-keys -t "${SESSION}:Python" \
        "echo '  Django shell via docker-compose...'" Enter
      tmux send-keys -t "${SESSION}:Python" \
        "$DC_CMD -f $COMPOSE_FILE exec $DOCKER_SERVICE python manage.py shell" Enter
    else
      tmux send-keys -t "${SESSION}:Python" \
        "echo '  Python via docker-compose...'" Enter
      tmux send-keys -t "${SESSION}:Python" \
        "$DC_CMD -f $COMPOSE_FILE exec $DOCKER_SERVICE python" Enter
    fi
  else
    # Direct Python execution
    if command -v ipython &>/dev/null; then
      PYTHON_CMD="ipython"
    elif command -v bpython &>/dev/null; then
      PYTHON_CMD="bpython"
    fi
    
    if [[ "$HAS_DJANGO" == true ]]; then
      tmux send-keys -t "${SESSION}:Python" \
        "echo '  Django shell (use: python manage.py shell_plus for ipython)...'" Enter
      tmux send-keys -t "${SESSION}:Python" \
        "$PYTHON_CMD manage.py shell" Enter
    else
      tmux send-keys -t "${SESSION}:Python" "$PYTHON_CMD" Enter
    fi
  fi
fi

# ── Window 5: Tests ─────────────────────────────────────────────────────────
if [[ "$HAS_TESTS" == true || "$HAS_DJANGO" == true || "$HAS_PYTHON" == true ]]; then
  tmux new-window -t "$SESSION" -n "Tests" -c "$PROJECT_DIR"
  
  if [[ "$HAS_COMPOSE" == true && -n "$DOCKER_SERVICE" ]]; then
    # Docker-based testing
    if [[ -f "$PROJECT_DIR/pytest.ini" || -f "$PROJECT_DIR/pyproject.toml" ]]; then
      tmux send-keys -t "${SESSION}:Tests" \
        "echo '  Running pytest via docker-compose...'" Enter
      tmux send-keys -t "${SESSION}:Tests" \
        "$DC_CMD -f $COMPOSE_FILE exec $DOCKER_SERVICE pytest" Enter
    elif [[ "$HAS_DJANGO" == true ]]; then
      tmux send-keys -t "${SESSION}:Tests" \
        "echo '  Running Django tests via docker-compose...'" Enter
      tmux send-keys -t "${SESSION}:Tests" \
        "$DC_CMD -f $COMPOSE_FILE exec $DOCKER_SERVICE python manage.py test" Enter
    else
      tmux send-keys -t "${SESSION}:Tests" \
        "echo '  Run tests: $DC_CMD -f $COMPOSE_FILE exec $DOCKER_SERVICE pytest'" Enter
    fi
  else
    # Direct execution
    if [[ -f "$PROJECT_DIR/pytest.ini" || -f "$PROJECT_DIR/pyproject.toml" ]]; then
      tmux send-keys -t "${SESSION}:Tests" "pytest" Enter
    elif [[ "$HAS_DJANGO" == true ]]; then
      tmux send-keys -t "${SESSION}:Tests" "python manage.py test" Enter
    else
      tmux send-keys -t "${SESSION}:Tests" "echo '  Run tests here (pytest, unittest, etc.)'" Enter
    fi
  fi
fi

# ── Window 6: Docker Logs (optional, for non-lazydocker users) ───────────────
if [[ "$HAS_COMPOSE" == true ]]; then
  if ! command -v lazydocker &>/dev/null; then
    tmux new-window -t "$SESSION" -n "Logs" -c "$PROJECT_DIR"
    tmux send-keys -t "${SESSION}:Logs" \
      "$DC_CMD -f $COMPOSE_FILE logs -f --tail=50" Enter
  fi
fi

# ── Focus IDE, attach ─────────────────────────────────────────────────────────
tmux select-window -t "${SESSION}:IDE"
[[ -n "$TMUX" ]] && tmux switch-client -t "$SESSION" \
  || tmux attach-session -t "$SESSION"
