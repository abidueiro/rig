#!/usr/bin/env bash
# =============================================================================
# rig template: django-dev
# Full Django/Docker development workflow in tmux with IDE-style first window.
#
# Windows:
#   1. IDE      — top 75%: helix editor | bottom 25%: opencode
#   2. compose  — docker-compose up | filtered logs (django + celery)
#   3. docker   — lazydocker
#   4. git      — gitui (only if git repo found)
#   5. python   — Django shell or Python REPL
#   6. tests    — Test runner
#   7. prod     — SSH to production (from .env or prompt)
#
# Run from your project directory, or pass it as argument.
# =============================================================================

PROJECT_DIR="${1:-$PWD}"
PROJECT_NAME="${2:-$(basename "$PROJECT_DIR")}"
SESSION="$PROJECT_NAME"

# ── Guard: tmux ─────────────────────────────────────────────────────────────
if ! command -v tmux &>/dev/null; then
  echo "  ✗ tmux is not installed." >&2; exit 1
fi

# ── Guard: project dir must exist ───────────────────────────────────────────
if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "  ✗ Project directory not found: $PROJECT_DIR" >&2; exit 1
fi

cd "$PROJECT_DIR" || exit 1

# ── Already exists: just attach ────────────────────────────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "  Session '$SESSION' already exists — connecting..."
  [[ -n "$TMUX" ]] && tmux switch-client -t "$SESSION" \
    || tmux attach-session -t "$SESSION"
  exit 0
fi

# ── Detect compose file(s) ─────────────────────────────────────────────────
COMPOSE_FILES=()
for candidate in \
  "docker-compose.development.yml" \
  "docker-compose.dev.yml" \
  "docker-compose.local.yml" \
  "docker-compose.yml" \
  "compose.yml"; do
  [[ -f "$PROJECT_DIR/$candidate" ]] && COMPOSE_FILES+=("$candidate")
done

COMPOSE_FILE=""
HAS_COMPOSE=false
if [[ ${#COMPOSE_FILES[@]} -eq 0 ]]; then
  echo "  ℹ No compose file found in $PROJECT_DIR — compose window will show a message."
elif [[ ${#COMPOSE_FILES[@]} -eq 1 ]]; then
  COMPOSE_FILE="${COMPOSE_FILES[0]}"
  HAS_COMPOSE=true
else
  # Multiple files — ask which one
  if command -v gum &>/dev/null; then
    COMPOSE_FILE=$(printf '%s\n' "${COMPOSE_FILES[@]}" \
      | gum choose --header "  Multiple compose files found — which one?")
    [[ -n "$COMPOSE_FILE" ]] && HAS_COMPOSE=true
  else
    COMPOSE_FILE="${COMPOSE_FILES[0]}"
    HAS_COMPOSE=true
    echo "  Multiple compose files found. Using: $COMPOSE_FILE"
    sleep 2
  fi
fi

# ── Detect docker-compose command (v1 vs v2) ────────────────────────────────
DC_CMD="docker-compose"
if command -v docker &>/dev/null && docker compose version &>/dev/null 2>&1; then
  DC_CMD="docker compose"
fi

# ── Detect git repo ─────────────────────────────────────────────────────────
HAS_GIT=false
git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null 2>&1 && HAS_GIT=true

# ── Detect production host from .env ─────────────────────────────────────────
PROD_HOST="" PROD_USER="root"
if [[ -f "$PROJECT_DIR/.env" ]]; then
  for var in PRODUCTION_HOST SSH_HOST DEPLOY_HOST REMOTE_HOST; do
    val=$(grep -E "^${var}=" "$PROJECT_DIR/.env" 2>/dev/null \
      | head -1 | cut -d'=' -f2 | tr -d '"'"'"'"'"'"'')'
    if [[ -n "$val" ]]; then PROD_HOST="$val"; break; fi
  done
  for var in PRODUCTION_USER SSH_USER DEPLOY_USER; do
    val=$(grep -E "^${var}=" "$PROJECT_DIR/.env" 2>/dev/null \
      | head -1 | cut -d'=' -f2 | tr -d '"'"'"'"'"'"'')'
    if [[ -n "$val" ]]; then PROD_USER="$val"; break; fi
  done
fi

# ── Detect docker service name ──────────────────────────────────────────────
DOCKER_SERVICE=""
if [[ "$HAS_COMPOSE" == true && -f "$COMPOSE_FILE" ]]; then
  for svc in web django app api backend; do
    if grep -qE "^\s+${svc}:" "$COMPOSE_FILE" 2>/dev/null; then
      DOCKER_SERVICE="$svc"
      break
    fi
  done
fi

# ── Detect editor ───────────────────────────────────────────────────────────
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

# ── Summary before launching ──────────────────────────────────────────────────
echo ""
echo "  rig django-dev template"
echo "  ─────────────────────────────────────"
echo "  Session:  $SESSION"
echo "  Dir:      $PROJECT_DIR"
echo "  Editor:   $EDITOR_CMD (Space+f for fuzzy find)"
echo "  Compose:  ${COMPOSE_FILE:-not found}"
echo "  Service:  ${DOCKER_SERVICE:-none detected}"
echo "  Git repo: ${HAS_GIT}"
echo "  Prod:     ${PROD_HOST:-not set in .env}"
echo ""

# ── Create session ───────────────────────────────────────────────────────────
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -n "IDE"

# Enable mouse support for easy resizing
tmux set-option -t "$SESSION" -g mouse on

# ── Window 1: IDE (75/25 split) ─────────────────────────────────────────────
# Top pane (75%): Editor
tmux send-keys -t "${SESSION}:IDE" "$EDITOR_CMD ." Enter

# Bottom pane (25%): opencode
tmux split-window -v -t "${SESSION}:IDE" -c "$PROJECT_DIR" -p 25
if command -v opencode &>/dev/null; then
  tmux send-keys -t "${SESSION}:IDE" "opencode" Enter
else
  tmux send-keys -t "${SESSION}:IDE" \
    "echo '  ℹ opencode not installed — this is a free terminal'" Enter
fi

# Focus top pane (editor)
tmux select-pane -t "${SESSION}:IDE" -U 2>/dev/null || tmux select-pane -t "${SESSION}:IDE.0"

# ── Window 2: compose ───────────────────────────────────────────────────────
if [[ "$HAS_COMPOSE" == true ]]; then
  tmux new-window -t "$SESSION" -n "compose" -c "$PROJECT_DIR"
  # Top pane: docker-compose up
  tmux send-keys -t "${SESSION}:compose" \
    "$DC_CMD -f $COMPOSE_FILE up" Enter
  # Bottom pane (30%): filtered logs for django + celery
  tmux split-window -v -t "${SESSION}:compose" -c "$PROJECT_DIR" -p 30
  tmux send-keys -t "${SESSION}:compose" \
    "sleep 6 && ($DC_CMD -f $COMPOSE_FILE logs -f --tail=50 django celery worker 2>/dev/null \
     || $DC_CMD -f $COMPOSE_FILE logs -f --tail=50)" Enter
  # Focus top pane
  tmux select-pane -t "${SESSION}:compose" -U 2>/dev/null \
    || tmux select-pane -t "${SESSION}:compose.0"
else
  tmux new-window -t "$SESSION" -n "compose" -c "$PROJECT_DIR"
  tmux send-keys -t "${SESSION}:compose" \
    "echo '  ℹ No compose file found in $PROJECT_DIR'" Enter
  tmux send-keys -t "${SESSION}:compose" \
    "echo '  Start your services manually or add a docker-compose.yml'" Enter
fi

# ── Window 3: lazydocker ────────────────────────────────────────────────────
tmux new-window -t "$SESSION" -n "docker" -c "$PROJECT_DIR"
if command -v lazydocker &>/dev/null; then
  tmux send-keys -t "${SESSION}:docker" "lazydocker" Enter
else
  tmux send-keys -t "${SESSION}:docker" \
    "echo '  ℹ lazydocker not installed — showing docker ps' && watch -n2 docker ps" Enter
fi

# ── Window 4: gitui (only if git repo) ──────────────────────────────────────
if [[ "$HAS_GIT" == true ]]; then
  tmux new-window -t "$SESSION" -n "git" -c "$PROJECT_DIR"
  if command -v gitui &>/dev/null; then
    tmux send-keys -t "${SESSION}:git" "gitui" Enter
  elif command -v lazygit &>/dev/null; then
    tmux send-keys -t "${SESSION}:git" "lazygit" Enter
  else
    tmux send-keys -t "${SESSION}:git" \
      "echo '  ℹ gitui/lazygit not installed — showing git log' && git log --oneline --graph --all | head -30" Enter
  fi
fi

# ── Window 5: Python/Django shell ─────────────────────────────────────────────
tmux new-window -t "$SESSION" -n "python" -c "$PROJECT_DIR"
if [[ "$HAS_COMPOSE" == true && -n "$DOCKER_SERVICE" ]]; then
  tmux send-keys -t "${SESSION}:python" \
    "echo '  Django shell via docker-compose exec $DOCKER_SERVICE...'" Enter
  tmux send-keys -t "${SESSION}:python" \
    "$DC_CMD -f $COMPOSE_FILE exec $DOCKER_SERVICE python manage.py shell" Enter
else
  # Direct execution fallback
  PYTHON_CMD="python3"
  command -v ipython &>/dev/null && PYTHON_CMD="ipython"
  tmux send-keys -t "${SESSION}:python" \
    "echo '  Django shell ($PYTHON_CMD manage.py shell)...'" Enter
  tmux send-keys -t "${SESSION}:python" "$PYTHON_CMD manage.py shell" Enter
fi

# ── Window 6: Tests ─────────────────────────────────────────────────────────
tmux new-window -t "$SESSION" -n "tests" -c "$PROJECT_DIR"
if [[ "$HAS_COMPOSE" == true && -n "$DOCKER_SERVICE" ]]; then
  if [[ -f "$PROJECT_DIR/pytest.ini" ]]; then
    tmux send-keys -t "${SESSION}:tests" \
      "echo '  Run tests: $DC_CMD -f $COMPOSE_FILE exec $DOCKER_SERVICE pytest'" Enter
    tmux send-keys -t "${SESSION}:tests" \
      "$DC_CMD -f $COMPOSE_FILE exec $DOCKER_SERVICE pytest -v" Enter
  else
    tmux send-keys -t "${SESSION}:tests" \
      "echo '  Run tests: $DC_CMD -f $COMPOSE_FILE exec $DOCKER_SERVICE python manage.py test'" Enter
    tmux send-keys -t "${SESSION}:tests" \
      "$DC_CMD -f $COMPOSE_FILE exec $DOCKER_SERVICE python manage.py test -v 2" Enter
  fi
else
  tmux send-keys -t "${SESSION}:tests" \
    "echo '  Run tests: python manage.py test'" Enter
  tmux send-keys -t "${SESSION}:tests" "python manage.py test" Enter
fi

# ── Window 7: prod ───────────────────────────────────────────────────────────
tmux new-window -t "$SESSION" -n "prod" -c "$PROJECT_DIR"
if [[ -n "$PROD_HOST" ]]; then
  tmux send-keys -t "${SESSION}:prod" \
    "echo '  Production: ${PROD_USER}@${PROD_HOST} (from .env)' && \
     read -p '  Press Enter to connect... ' && \
     ssh ${PROD_USER}@${PROD_HOST}" ""
else
  tmux send-keys -t "${SESSION}:prod" \
    "echo '  ℹ No production host found in .env'" Enter
  tmux send-keys -t "${SESSION}:prod" \
    "echo '  Add PRODUCTION_HOST=myserver.com to .env, or type: ssh user@host'" Enter
fi

# ── Focus IDE, attach ─────────────────────────────────────────────────────────
tmux select-window -t "${SESSION}:IDE"
[[ -n "$TMUX" ]] && tmux switch-client -t "$SESSION" \
  || tmux attach-session -t "$SESSION"
