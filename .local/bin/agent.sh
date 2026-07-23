#!/usr/bin/env bash
# Run a coding agent (claude-code by default, or opencode) inside a disposable,
# rootless-Docker nixos/nix sandbox.
#
# Security model: the container sees the current project directory (mounted rw
# at /workspace) plus the credential/config files the chosen agent needs.
# Nothing else from $HOME enters the container. The agent runs as container-root,
# which rootless Docker maps to your unprivileged host uid, so files it creates
# in the project stay owned by you.
#
# Note: for claude we also mount ~/.claude.json (config + onboarding/trust state)
# so the TUI starts without the first-run wizard. That file also holds your MCP
# server configs and cross-project history, so the agent can read those — an
# accepted trade for a prompt-free start.
#
# Usage:
#   agent.sh                       # claude-code in $PWD
#   agent.sh -a opencode           # opencode in $PWD
#   agent.sh -- --resume           # pass everything after -- to the agent CLI
#   agent.sh -a opencode -- run "fix the build"
#
# Override the committer email with AGENT_GIT_EMAIL.
set -euo pipefail

# --- config ---------------------------------------------------------------
# nixos/nix pinned by digest (tag: latest, nix 2.35.1 as of writing).
IMAGE="nixos/nix@sha256:377d4887aca98f0dfa12971c1ea6d6a625a435d8b610d4c95a436843da6fbfd1"
STORE_VOL="agent-nix-store"   # global, shared Nix store cache across all projects
CACHE_VOL="agent-nix-cache"   # flake-input tarballs + eval cache (~/.cache/nix)
GIT_NAME="agent-sandbox"
GIT_EMAIL="${AGENT_GIT_EMAIL:-linus.thriemer@pentacor.de}"

# --- args -----------------------------------------------------------------
agent="claude"
PASSTHROUGH=()
while [ $# -gt 0 ]; do
  case "$1" in
    -a | --agent)
      agent="${2:-}"
      shift 2
      ;;
    --)
      shift
      PASSTHROUGH=("$@")
      break
      ;;
    -h | --help)
      # Print only the leading doc comment block (skip shebang, stop at first non-comment).
      awk 'NR==1{next} /^#/{sub(/^# ?/,"");print;next} {exit}' "$0"
      exit 0
      ;;
    *)
      echo "agent.sh: unknown argument '$1' (did you mean to put it after '--'?)" >&2
      exit 2
      ;;
  esac
done

# --- credential mounts (per agent) ---------------------------------------
# Only the one file the agent needs; mounted rw so token refresh persists.
CRED_MOUNTS=()
need_file() {
  if [ ! -e "$1" ]; then
    echo "agent.sh: required credential '$1' not found — log in with the agent on the host first." >&2
    exit 1
  fi
}
case "$agent" in
  claude)
    need_file "$HOME/.claude/.credentials.json"
    CRED_MOUNTS+=(-v "$HOME/.claude/.credentials.json:/root/.claude/.credentials.json")
    # Config + onboarding/trust state (skips the first-run wizard). Also carries
    # mcpServers + project history into the sandbox; mounted rw so claude can
    # persist its own state.
    if [ -e "$HOME/.claude.json" ]; then
      CRED_MOUNTS+=(-v "$HOME/.claude.json:/root/.claude.json")
    fi
    ;;
  opencode)
    need_file "$HOME/.local/share/opencode/auth.json"
    CRED_MOUNTS+=(-v "$HOME/.local/share/opencode/auth.json:/root/.local/share/opencode/auth.json")
    # opencode.jsonc is config, not a secret — mount read-only if present.
    if [ -e "$HOME/.config/opencode/opencode.jsonc" ]; then
      CRED_MOUNTS+=(-v "$HOME/.config/opencode/opencode.jsonc:/root/.config/opencode/opencode.jsonc:ro")
    fi
    ;;
  *)
    echo "agent.sh: unknown agent '$agent' (expected 'claude' or 'opencode')" >&2
    exit 2
    ;;
esac

# --- entrypoint (dereference the stow symlink so the bind-mount resolves) --
ENTRYPOINT="$(dirname "$(readlink -f "$0")")/agent-entrypoint.sh"
if [ ! -e "$ENTRYPOINT" ]; then
  echo "agent.sh: entrypoint not found at '$ENTRYPOINT'" >&2
  exit 1
fi

# --- named volumes (idempotent) ------------------------------------------
docker volume create "$STORE_VOL" >/dev/null
docker volume create "$CACHE_VOL" >/dev/null

# --- run ------------------------------------------------------------------
exec docker run --rm -it \
  --security-opt=no-new-privileges \
  `# --cap-drop=ALL   # deferred; safe to enable (image has sandbox=false), left off for the first cut` \
  -v "$STORE_VOL":/nix \
  -v "$CACHE_VOL":/root/.cache/nix \
  -v "$PWD":/workspace \
  -w /workspace \
  -v "$ENTRYPOINT":/agent-entrypoint.sh:ro \
  "${CRED_MOUNTS[@]}" \
  -e AGENT="$agent" \
  -e GIT_NAME="$GIT_NAME" \
  -e GIT_EMAIL="$GIT_EMAIL" \
  --entrypoint /agent-entrypoint.sh \
  "$IMAGE" \
  ${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}
