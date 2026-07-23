#!/usr/bin/env bash
# In-container bootstrap for agent.sh. Runs as root inside the nixos/nix
# sandbox. Provisions direnv + nix-direnv + the selected agent into the
# persistent /nix volume (downloaded once, cached forever), sets up a
# throwaway git identity, trusts and loads the project's direnv environment,
# then execs the agent with that environment applied.
#
# Environment (set by agent.sh):
#   AGENT       claude | opencode
#   GIT_NAME    committer name
#   GIT_EMAIL   committer email
# Passthrough args to the agent CLI arrive as "$@".
set -euo pipefail

# The nixos/nix image doesn't enable these by default (the host does); flake refs
# and `nix profile` need them.
export NIX_CONFIG="experimental-features = nix-command flakes"

NIXPKGS="github:NixOS/nixpkgs/nixos-26.05"

# --- provision tools into the persistent store ---------------------------
# Guards make this a no-op once the store volume is warm.
command -v direnv >/dev/null 2>&1 || nix profile install "$NIXPKGS#direnv"

# nix-direnv ships no binary; detect it via its direnvrc in the profile.
NIX_DIRENV_RC="$HOME/.nix-profile/share/nix-direnv/direnvrc"
[ -e "$NIX_DIRENV_RC" ] || nix profile install "$NIXPKGS#nix-direnv"

case "$AGENT" in
  claude)
    AGENT_BIN="claude"
    AGENT_ATTR="claude-code"
    ;;
  opencode)
    AGENT_BIN="opencode"
    AGENT_ATTR="opencode"
    ;;
  *)
    echo "agent-entrypoint: unknown AGENT '$AGENT'" >&2
    exit 2
    ;;
esac
# claude-code is unfree in nixpkgs; --impure lets the flake eval read the env var.
command -v "$AGENT_BIN" >/dev/null 2>&1 ||
  NIXPKGS_ALLOW_UNFREE=1 nix profile install --impure "$NIXPKGS#$AGENT_ATTR"

# --- wire nix-direnv so `use flake`/`use nix` hit the fast cached path ----
mkdir -p "$HOME/.config/direnv"
if ! grep -qs 'nix-direnv/direnvrc' "$HOME/.config/direnv/direnvrc" 2>/dev/null; then
  echo "source \"$NIX_DIRENV_RC\"" >>"$HOME/.config/direnv/direnvrc"
fi

# --- throwaway git identity (local commits work; no keys => no push) ------
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global --add safe.directory /workspace

# --- trust + load the project env, then launch the agent ------------------
cd /workspace
if [ -f .envrc ]; then
  direnv allow . || true
fi
exec direnv exec /workspace "$AGENT_BIN" "$@"
