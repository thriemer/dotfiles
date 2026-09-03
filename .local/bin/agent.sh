#!/usr/bin/env bash
# Run a coding agent (claude-code by default, or opencode/pi) inside a
# lightweight bubblewrap sandbox that shares the host's Nix store.
#
# Security model: the sandbox sees the current project directory (bind-mounted
# read-write at its real path) plus the credential files the chosen agent needs.
# $HOME is a tmpfs, so nothing else from your home directory exists inside the
# namespace at all. Everything else -- /nix/store, /etc, the system profile --
# is read-only, so `rm -rf /` fails with EROFS.
#
# Unlike the Docker variant this shares the host's /nix/store read-only instead
# of maintaining a second store in a volume, so project dependencies are not
# duplicated on disk. Builds are delegated to the host nix-daemon through its
# socket, which keeps `use flake`, `nix shell` and `nix-shell -p` working; new
# store paths appear in the sandbox immediately through the bind mount.
#
# The project and $HOME keep the exact paths they have on the host, rather than
# being remapped to a fixed location. The nix-daemon resolves paths in its own
# namespace, so GC roots for `result` symlinks and nix-direnv's .direnv/ profile
# links only survive if both sides agree on the path.
#
# Usage:
#   agent.sh                      # claude-code in $PWD
#   agent.sh -a opencode          # opencode in $PWD
#   agent.sh -a pi                # pi in $PWD
#   agent.sh -ro /path            # read-only-bind host path at the same path
#   agent.sh -rw /path            # read-write-bind host path at the same path
#   agent.sh -- --resume 5        # pass everything after -- to the agent CLI
#   agent.sh -c "make test"       # run a command in the sandbox instead
#
# Override the committer email with AGENT_GIT_EMAIL.
# Set AGENT_SANDBOX_DRY_RUN=1 to print the assembled bwrap command instead of
# running it.
set -euo pipefail

# --- config ---------------------------------------------------------------
GIT_NAME="agent-sandbox"
GIT_EMAIL="${AGENT_GIT_EMAIL:-linus.thriemer@pentacor.de}"

# Small persistent state outside the tmpfs home: nix eval/tarball cache and
# direnv's allow-list. Metadata only -- this is the replacement for the
# agent-nix-cache volume, not for the store volume.
STATE_DIR="${AGENT_SANDBOX_STATE:-${XDG_CACHE_HOME:-$HOME/.cache}/agent-sandbox}"

PROG="${0##*/}"

die() {
  echo "$PROG: $*" >&2
  exit 1
}

warn() {
  echo "$PROG: warning: $*" >&2
}

# --- args -----------------------------------------------------------------
agent="claude"
PASSTHROUGH=()
EXEC_CMD=""
DATA_BINDS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -a | --agent)
      agent="${2:-}"
      shift 2
      ;;
    -c | --cmd)
      EXEC_CMD="${2:-}"
      [ -n "$EXEC_CMD" ] || die "--cmd requires a command string"
      shift 2
      ;;
    -ro | --ro)
      [ -e "${2:-}" ] || die "--ro path '${2:-}' does not exist"
      DATA_BINDS+=(--ro-bind "$2" "$2")
      shift 2
      ;;
    -rw | --rw)
      [ -e "${2:-}" ] || die "--rw path '${2:-}' does not exist"
      DATA_BINDS+=(--bind "$2" "$2")
      shift 2
      ;;
    --)
      shift
      PASSTHROUGH=("$@")
      break
      ;;
    -h | --help)
      # Print the leading doc comment block (skip the shebang, stop at the
      # first non-comment line). Pure bash so this works before any PATH setup.
      {
        read -r _shebang
        while IFS= read -r line; do
          [[ $line == \#* ]] || break
          line="${line###}"
          printf '%s\n' "${line# }"
        done
      } <"$0"
      exit 0
      ;;
    *)
      die "unknown argument '$1' (did you mean to put it after '--'?)"
      ;;
  esac
done

command -v bwrap >/dev/null 2>&1 || die "bwrap not found -- add pkgs.bubblewrap to your system packages"

# --- resolve host binaries before the sandbox hides $HOME -----------------
# Agents installed into the user profile live under ~/.nix-profile/bin, which
# the tmpfs home would swallow. Resolving to the /nix/store realpath here means
# the exec target stays valid inside.
resolve_bin() {
  local p
  p="$(command -v "$1" 2>/dev/null)" || die "'$1' not found on PATH -- install it on the host first"
  readlink -f "$p"
}

case "$agent" in
  claude) AGENT_BIN="claude" ;;
  opencode) AGENT_BIN="opencode" ;;
  pi) AGENT_BIN="pi" ;;
  *) die "unknown agent '$agent' (expected 'claude', 'opencode', or 'pi')" ;;
esac

AGENT_PATH="$(resolve_bin "$AGENT_BIN")"
DIRENV_PATH="$(resolve_bin direnv)"
BASH_PATH="$(resolve_bin bash)"

# --- credential binds (per agent) ----------------------------------------
# Only the files the agent needs, read-write so token refresh persists.
CRED_BINDS=()
need_file() {
  [ -e "$1" ] || die "required credential '$1' not found -- log in with the agent on the host first."
}
bind_rw_if_present() {
  [ -e "$1" ] && CRED_BINDS+=(--bind "$1" "$1")
  return 0
}

case "$agent" in
  claude)
    need_file "$HOME/.claude/.credentials.json"
    CRED_BINDS+=(--bind "$HOME/.claude/.credentials.json" "$HOME/.claude/.credentials.json")
    # Config + onboarding/trust state (skips the first-run wizard). Also carries
    # mcpServers + project history into the sandbox; bound rw so claude can
    # persist its own state. Same trade-off as the Docker variant.
    bind_rw_if_present "$HOME/.claude.json"
    ;;
  opencode)
    need_file "$HOME/.local/share/opencode/auth.json"
    CRED_BINDS+=(--bind "$HOME/.local/share/opencode/auth.json" "$HOME/.local/share/opencode/auth.json")
    [ -e "$HOME/.config/opencode/opencode.jsonc" ] &&
      CRED_BINDS+=(--ro-bind "$HOME/.config/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc")
    ;;
  pi)
    need_file "$HOME/.pi/agent/auth.json"
    CRED_BINDS+=(--bind "$HOME/.pi" "$HOME/.pi")
    ;;
esac

# --- persistent state (metadata only, no store copy) ----------------------
mkdir -p "$STATE_DIR/nix" "$STATE_DIR/direnv"

# --- nix wiring -----------------------------------------------------------
NIX_SOCKET_DIR=/nix/var/nix/daemon-socket
NIX_BINDS=(--ro-bind /nix/store /nix/store)
if [ -S "$NIX_SOCKET_DIR/socket" ]; then
  # Write access on the socket is required to connect(); the directory itself
  # is the smallest thing we can hand over.
  NIX_BINDS+=(--bind "$NIX_SOCKET_DIR" "$NIX_SOCKET_DIR")
else
  warn "no nix-daemon socket at $NIX_SOCKET_DIR/socket."
  echo "  The store will be strictly read-only -- 'nix shell' and 'use flake' can" >&2
  echo "  only use paths that are already realised." >&2
fi
# Read-only: user profile bin dirs and channels stay reachable, but the agent
# cannot swap a profile generation (`nix profile install` fails, by design).
[ -d /nix/var/nix/profiles ] && NIX_BINDS+=(--ro-bind /nix/var/nix/profiles /nix/var/nix/profiles)

# --- nix-direnv wiring ----------------------------------------------------
# The Docker entrypoint installed nix-direnv and wrote its own direnvrc. Here the
# tmpfs home starts empty, so we either carry the host's wiring in read-only or
# regenerate a one-liner inside. Without it `use flake` still works, but
# uncached -- noticeably slow on every cd.
DIRENV_CONF_BIND=()
SB_NIX_DIRENV_RC=""
if [ -f "$HOME/.config/direnv/direnvrc" ]; then
  # Host wiring wins; the file usually symlinks into the (bound) store.
  DIRENV_CONF_BIND=(--ro-bind "$HOME/.config/direnv" "$HOME/.config/direnv")
elif [ -f /etc/direnv/direnvrc ]; then
  : # programs.direnv.nix-direnv.enable -- already covered by the /etc bind.
else
  for c in "$HOME/.nix-profile/share/nix-direnv/direnvrc" \
    /run/current-system/sw/share/nix-direnv/direnvrc; do
    [ -e "$c" ] && SB_NIX_DIRENV_RC="$c" && break
  done
  [ -n "$SB_NIX_DIRENV_RC" ] ||
    warn "no nix-direnv found -- 'use flake' will run uncached."
fi

# --- environment ----------------------------------------------------------
# --clearenv means nothing leaks in implicitly (SSH_AUTH_SOCK, AWS_*, ...), so
# every variable the agent needs is listed here explicitly.
SANDBOX_PATH="/run/current-system/sw/bin:$HOME/.nix-profile/bin:$(dirname "$AGENT_PATH"):$(dirname "$DIRENV_PATH")"

ENV_ARGS=(
  --setenv HOME "$HOME"
  --setenv USER "${USER:-$(id -un)}"
  --setenv PATH "$SANDBOX_PATH"
  --setenv TERM "${TERM:-xterm-256color}"
  --setenv NIX_REMOTE daemon
  --setenv GIT_AUTHOR_NAME "$GIT_NAME"
  --setenv GIT_AUTHOR_EMAIL "$GIT_EMAIL"
  --setenv GIT_COMMITTER_NAME "$GIT_NAME"
  --setenv GIT_COMMITTER_EMAIL "$GIT_EMAIL"
  --setenv XDG_RUNTIME_DIR "/run/user/$(id -u)"
  # Everything the inner script needs, so that it can stay a literal string
  # without a single interpolation -- see the INNER comment below.
  --setenv SB_DIRENV "$DIRENV_PATH"
  --setenv SB_BASH "$BASH_PATH"
  --setenv SB_AGENT "$AGENT_PATH"
  --setenv SB_PROJ "$PWD"
  --setenv SB_NIX_DIRENV_RC "$SB_NIX_DIRENV_RC"
)
# NIX_PATH is gone with --clearenv; without <nixpkgs> the classic `nix-shell -p`
# aborts with "file 'nixpkgs' was not found".
ENV_ARGS+=(--setenv NIX_PATH "${NIX_PATH:-nixpkgs=flake:nixpkgs}")

pass_env() {
  [ -n "${!1:-}" ] && ENV_ARGS+=(--setenv "$1" "${!1}")
  return 0
}
for v in LANG LC_ALL TZ COLORTERM SSL_CERT_FILE NIX_SSL_CERT_FILE; do
  pass_env "$v"
done

# --- run ------------------------------------------------------------------
# Note on --new-session: deliberately omitted. setsid() detaches the controlling
# terminal, which breaks Ctrl-C and job control in an interactive TUI. It guards
# against TIOCSTI injection into the host terminal, but that ioctl is disabled
# kernel-wide by default since 6.2 (dev.tty.legacy_tiocsti=0) -- check with
# `sysctl dev.tty.legacy_tiocsti` if in doubt.
#
# --unshare-all implies --unshare-net, so --share-net has to come after it;
# without network the agent cannot reach its API.
BWRAP_ARGS=(
  --unshare-all --share-net
  --die-with-parent
  --clearenv
  --proc /proc
  --dev /dev
  --tmpfs /tmp
  --tmpfs "/run/user/$(id -u)"
  "${NIX_BINDS[@]}"
  --ro-bind /etc /etc
  --ro-bind-try /bin /bin
  --ro-bind-try /usr /usr
  --ro-bind-try /run/current-system /run/current-system
  --ro-bind-try /run/systemd/resolve /run/systemd/resolve
  # tmpfs home first, then punch the few allowed files back through it --
  # bwrap applies operations in order and creates mount points itself.
  --tmpfs "$HOME"
  --symlink /nix/var/nix/profiles/per-user/"${USER:-$(id -un)}"/profile "$HOME/.nix-profile"
  "${DIRENV_CONF_BIND[@]}"
  # Plain config, read-only: editor, aliases, nix-direnv wiring. Drop this line
  # if your gitconfig carries credential helpers you would rather not expose.
  --ro-bind-try "$HOME/.gitconfig" "$HOME/.gitconfig"
  --bind "$STATE_DIR/nix" "$HOME/.cache/nix"
  --bind "$STATE_DIR/direnv" "$HOME/.local/share/direnv"
  "${CRED_BINDS[@]}"
  "${DATA_BINDS[@]}"
  --bind "$PWD" "$PWD"
  --chdir "$PWD"
  "${ENV_ARGS[@]}"
)

# The bootstrap that runs inside the sandbox: wire up nix-direnv if needed,
# trust the project's .envrc, then hand over to the agent.
#
# Deliberately a *literal* single-quoted string -- not one value is interpolated,
# everything arrives through the SB_* variables set above. That keeps the quoting
# flat no matter what a path or a --cmd string contains, and avoids a second file
# that would have to be bind-mounted in and kept next to this one.
#
# `direnv allow` runs unattended: the sandbox is the trust boundary here, so an
# .envrc inside it is no more privileged than the code the agent already edits.
INNER='
set -eu
if [ -n "${SB_NIX_DIRENV_RC:-}" ]; then
  mkdir -p "$HOME/.config/direnv"
  echo "source \"$SB_NIX_DIRENV_RC\"" > "$HOME/.config/direnv/direnvrc"
fi
if [ -f .envrc ]; then "$SB_DIRENV" allow . || true; fi
if [ -n "${EXEC_CMD:-}" ]; then
  exec "$SB_DIRENV" exec "$SB_PROJ" "$SB_BASH" -c "$EXEC_CMD"
fi
exec "$SB_DIRENV" exec "$SB_PROJ" "$SB_AGENT" "$@"
'
if [ -n "$EXEC_CMD" ]; then
  BWRAP_ARGS+=(--setenv EXEC_CMD "$EXEC_CMD")
fi

if [ -n "${AGENT_SANDBOX_DRY_RUN:-}" ]; then
  printf 'bwrap'
  printf ' %q' "${BWRAP_ARGS[@]}" "$BASH_PATH" -c "$INNER" -- ${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}
  printf '\n'
  exit 0
fi

exec bwrap "${BWRAP_ARGS[@]}" \
  "$BASH_PATH" -c "$INNER" -- ${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}
