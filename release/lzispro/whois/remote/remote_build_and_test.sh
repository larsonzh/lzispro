#!/usr/bin/env bash
set -euo pipefail

# Git Bash friendly local launcher for remote static cross-compile and tests.
# Requirements on Windows: Git Bash with OpenSSH (ssh/scp) available in PATH.
# Requirements on Ubuntu VM: musl toolchains, file, strip, optional upx/qemu.

###############################################################################
# Defaults (can be overridden by flags or env vars). Zero-arg run executes full build.
###############################################################################
SSH_HOST=${SSH_HOST:-"10.0.0.199"}
SSH_USER=${SSH_USER:-"larson"}
SSH_PORT=${SSH_PORT:-22}
SSH_KEY=${SSH_KEY:-""}        # e.g. /d/Larson/id_rsa (optional)
REMOTE_DIR=${REMOTE_DIR:-""}  # if empty, will use $HOME/lzispro_remote
TARGETS=${TARGETS:-"aarch64 armv7 x86_64 x86 mipsel mips64el loongarch64"}
RUN_TESTS=${RUN_TESTS:-0}
OUTPUT_DIR=${OUTPUT_DIR:-"release/build_out"}
FETCH_TO=${FETCH_TO:-"release/artifacts"}

###############################################################################
# Args parsing (simple getopts)
###############################################################################
print_help() {
  cat <<EOF
Usage: $(basename "$0") [options] [keyfile]

Options:
  -H <host>          SSH host (default: $SSH_HOST)
  -u <user>          SSH user (default: $SSH_USER)
  -p <port>          SSH port (default: $SSH_PORT)
  -k <key>           SSH private key path (optional)
  -R <remote_dir>    Remote base dir (default: use remote \$HOME/lzispro_remote)
  -t <targets>       Space-separated targets (default: "$TARGETS")
  -r <0|1>           Run smoke tests (default: $RUN_TESTS)
  -o <output_dir>    Remote output dir (default: $OUTPUT_DIR)
  -f <fetch_to>      Local artifacts base dir (default: $FETCH_TO)
  -h                 Show this help

Notes:
  - Run with NO options to build all targets and run smoke tests using defaults.
  - You may pass a single positional [keyfile] instead of -k to specify the SSH key.
EOF
}

while getopts ":H:u:p:k:R:t:r:o:f:h" opt; do
  case $opt in
    H) SSH_HOST="$OPTARG" ;;
    u) SSH_USER="$OPTARG" ;;
    p) SSH_PORT="$OPTARG" ;;
    k) SSH_KEY="$OPTARG" ;;
    R) REMOTE_DIR="$OPTARG" ;;
    t) TARGETS="$OPTARG" ;;
    r) RUN_TESTS="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    f) FETCH_TO="$OPTARG" ;;
    h) print_help; exit 0 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; exit 2 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; print_help; exit 2 ;;
  esac
done

# Support a single positional argument as keyfile for convenience
shift $((OPTIND-1))
if (( $# >= 1 )) && [[ -z "${SSH_KEY}" ]]; then
  if [[ -f "$1" ]]; then
    SSH_KEY="$1"
  fi
fi

log() { echo "[remote_build] $*"; }
warn() { echo "[remote_build][WARN] $*" >&2; }
err() { echo "[remote_build][ERROR] $*" >&2; }

###############################################################################
# Helper: run a remote command via bash -lc with robust quoting
# Ensures the entire -c payload is a single argument on remote side
###############################################################################
run_remote_lc() {
  local payload="$1"
  # Escape single quotes for safe wrapping in single quotes: ' -> '\''
  local esc
  esc=${payload//\'/\'"\'"\'}
  "${SSH_BASE[@]}" "$REMOTE_HOST" "bash -lc '$esc'"
}

###############################################################################
# Resolve local repo root (script is under release/lzispro/whois/remote)
###############################################################################
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
REPO_NAME="$(basename "$REPO_ROOT")"
log "Repo root: $REPO_ROOT"

###############################################################################
# Assemble ssh/scp base commands
###############################################################################
SSH_BASE=(ssh -p "$SSH_PORT")
SCP_BASE=(scp -P "$SSH_PORT")
if [[ -n "$SSH_KEY" ]]; then
  SSH_BASE+=(-i "$SSH_KEY")
  SCP_BASE+=(-i "$SSH_KEY")
fi
# Avoid interactive host key prompt and avoid writing known_hosts under non-ASCII paths
SSH_BASE+=(-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR)
SCP_BASE+=(-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR)
REMOTE_HOST="${SSH_USER}@${SSH_HOST}"

###############################################################################
# 1) Detect remote HOME and compute base dir
###############################################################################
log "Check SSH authentication"
if ! "${SSH_BASE[@]}" "$REMOTE_HOST" bash -lc "echo ok" >/dev/null 2>&1; then
  err "SSH authentication failed (no key/agent). Use -k /d/xxx/id_rsa or configure ssh-agent."
  exit 1
fi

log "Detect remote HOME"
# Try several robust methods to get absolute HOME path on remote
REMOTE_HOME="$("${SSH_BASE[@]}" "$REMOTE_HOST" bash -lc "cd ~ && pwd")"
if [[ -z "$REMOTE_HOME" ]]; then
  REMOTE_HOME="$("${SSH_BASE[@]}" "$REMOTE_HOST" sh -lc "cd ~ && pwd")"
fi
if [[ -z "$REMOTE_HOME" ]]; then
  REMOTE_HOME="$("${SSH_BASE[@]}" "$REMOTE_HOST" sh -lc "getent passwd \"\$USER\" | cut -d: -f6")"
fi
if [[ -z "$REMOTE_HOME" ]]; then
  REMOTE_HOME="/home/$SSH_USER"
fi
# Sanitize possible CR/LF from remote output
REMOTE_HOME="$(printf %s "$REMOTE_HOME" | tr -d '\r\n')"
if [[ -z "$REMOTE_HOME" ]]; then err "Failed to determine remote HOME (empty)."; exit 1; fi
REMOTE_BASE="$REMOTE_HOME/lzispro_remote"
if [[ -n "$REMOTE_DIR" ]]; then REMOTE_BASE="$REMOTE_DIR"; fi

###############################################################################
# 2) Create remote working dir
###############################################################################
log "Create remote work dir: $REMOTE_BASE/src"
run_remote_lc "mkdir -p $REMOTE_BASE/src"

###############################################################################
# 3) Upload whole repo to remote/src (exclude .git to avoid permission issues)
###############################################################################
log "Upload repository (excluding .git and artifacts)"
LOCAL_PARENT_DIR="$(cd "$REPO_ROOT/.." && pwd)"
EXCLUDES=("--exclude=$REPO_NAME/.git" "--exclude=$REPO_NAME/release/artifacts")
# Stream a tarball over SSH to avoid copying .git objects and preserve permissions cleanly
tar -C "$LOCAL_PARENT_DIR" -cf - "${EXCLUDES[@]}" "$REPO_NAME" | \
  run_remote_lc "mkdir -p $REMOTE_BASE/src && tar -C $REMOTE_BASE/src -xf -"

REMOTE_REPO_DIR="$REMOTE_BASE/src/$REPO_NAME"

###############################################################################
# 4) Run remote build script (send tiny script via stdin to avoid -lc quoting)
###############################################################################
log "Remote build and optional tests"
"${SSH_BASE[@]}" "$REMOTE_HOST" bash -l -s <<EOF
set -e
cd "$REMOTE_REPO_DIR"
chmod +x release/lzispro/whois/remote/remote_build.sh
TARGETS='$TARGETS' RUN_TESTS=$RUN_TESTS OUTPUT_DIR='$OUTPUT_DIR' ./release/lzispro/whois/remote/remote_build.sh
EOF

###############################################################################
# 5) Fetch artifacts back to local
###############################################################################
timestamp="$(date +%Y%m%d-%H%M%S)"
LOCAL_ARTIFACTS_DIR="$REPO_ROOT/$FETCH_TO/$timestamp"
mkdir -p "$LOCAL_ARTIFACTS_DIR"
REMOTE_ARTIFACTS="$REMOTE_REPO_DIR/$OUTPUT_DIR/"
log "Fetch artifacts -> $LOCAL_ARTIFACTS_DIR"
"${SCP_BASE[@]}" -r "$REMOTE_HOST:$REMOTE_ARTIFACTS" "$LOCAL_ARTIFACTS_DIR/"

###############################################################################
# 6) Remote cleanup
###############################################################################
log "Remote cleanup: rm -rf $REMOTE_BASE"
run_remote_lc "rm -rf $REMOTE_BASE"

log "All done. Artifacts saved to: $LOCAL_ARTIFACTS_DIR"

# Optional: show a short smoke test tail when tests are enabled
if [[ "$RUN_TESTS" == "1" ]]; then
  if [[ -s "$LOCAL_ARTIFACTS_DIR/build_out/smoke_test.log" ]]; then
    echo "[remote_build] Smoke test tail (last 40 lines):"
    tail -n 40 "$LOCAL_ARTIFACTS_DIR/build_out/smoke_test.log" || true
  else
    echo "[remote_build][WARN] smoke_test.log is missing or empty"
  fi
fi
