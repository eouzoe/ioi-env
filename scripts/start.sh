#!/usr/bin/env sh
# ioi-env — student one-command bootstrap.
#
# Targets the competition environment (Ubuntu 24.04 + gcc13 + C++17), and works
# on any Linux — including WSL Ubuntu, where it also pins the Windows-side
# .wslconfig that keeps timing measurements stable.
#
# Usage (the one line a student runs):
#   curl -fsSL https://raw.githubusercontent.com/<owner>/ioi-env/main/scripts/start.sh | bash
#
# Overridable via env:
#   IOI_ENV_REPO        repo to clone (default: the one hosting this script)
#   IOI_ENV_DIR         where to put it (default: ~/ioi-env)
#   IOI_ENV_BRANCH      branch to fetch (default: main)
#   IOI_ENV_WSL_MEMORY  .wslconfig memory cap (default: 8GB)
#   IOI_ENV_NO_SHELL    set to 1 to stop before `devenv shell` (for CI)
#   GITHUB_TOKEN        only needed for a private repo; public repo: leave empty
#
# What it does, in order:
#   1. write the Windows-side .wslconfig (WSL only, no sudo needed)
#   2. install Nix (Determinate) if absent
#   3. install devenv
#   4. fetch this repo into ~/ioi-env
#   5. install the contest-grade ~/.vimrc (never clobbers an existing one)
#   6. print the two remaining sudo-only steps
#   7. enter the devenv shell
#
# It never prompts. `curl | bash` means stdin IS this script, so anything
# interactive would deadlock; the sudo-only steps are printed, not run.

set -eu

# ── config ───────────────────────────────────────────────────────────────────

REPO_OWNER="${IOI_ENV_OWNER:-eouzoe}"
REPO="${IOI_ENV_REPO:-https://github.com/${REPO_OWNER}/ioi-env}"
BRANCH="${IOI_ENV_BRANCH:-main}"
DEST="${IOI_ENV_DIR:-$HOME/ioi-env}"
WSL_MEM="${IOI_ENV_WSL_MEMORY:-8GB}"
NO_SHELL="${IOI_ENV_NO_SHELL:-0}"

log()   { printf '  %s\n' "$1"; }
head1() { printf '\n── %s ──\n' "$1"; }
die()   { printf '\nerror: %s\n' "$1" >&2; exit 1; }

# ── preflight ───────────────────────────────────────────────────────────────

command -v curl >/dev/null 2>&1 || die "curl is required (WSL Ubuntu ships it; else: sudo apt install curl)"
command -v tar  >/dev/null 2>&1 || die "tar is required (WSL Ubuntu ships it)"

printf '\n  ioi-env — one command to start.\n'
printf '  target: Ubuntu 24.04 + gcc 13.x + C++17  (competition spec)\n\n'

# WSL detection: the kernel release string carries "microsoft", and the C drive
# is mounted. Either signal is enough; on a bare Linux box both are absent, and
# every Windows-specific step below is skipped rather than faked.
IS_WSL=0
if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null || [ -d /mnt/c/Windows ]; then
  IS_WSL=1
fi

# ── 1. Windows-side .wslconfig ──────────────────────────────────────────────

if [ "$IS_WSL" = "1" ]; then
  head1 ".wslconfig (Windows side)"

  WIN_USER=""
  WIN_PROFILE=""
  if [ -x /mnt/c/Windows/System32/cmd.exe ]; then
    WIN_USER=$(/mnt/c/Windows/System32/cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r' || true)
  fi
  if [ -n "$WIN_USER" ] && [ -d "/mnt/c/Users/$WIN_USER" ]; then
    WIN_PROFILE="/mnt/c/Users/$WIN_USER"
  fi

  if [ -z "$WIN_PROFILE" ]; then
    log "could not locate the Windows profile — skipped (create .wslconfig by hand if you want this)"
  elif [ -f "$WIN_PROFILE/.wslconfig" ]; then
    log "$WIN_PROFILE/.wslconfig already exists — leaving it alone."
    log "to get the pinned values, merge these in:"
    printf '      [wsl2]\n      memory=%s\n      processors=4\n      swap=0\n' "$WSL_MEM"
  else
    # Write from Linux: a BOM or CRLF line endings make WSL silently ignore the
    # ENTIRE file, so this must never be produced by a Windows editor.
    cat > "$WIN_PROFILE/.wslconfig" <<EOF
[wsl2]
memory=$WSL_MEM
processors=4
swap=0
localhostForwarding=true
EOF
    log "wrote $WIN_PROFILE/.wslconfig (memory=$WSL_MEM, processors=4, swap=0)"
    log "takes effect after: wsl --shutdown  (from cmd, then reopen the terminal)"
  fi
else
  head1 ".wslconfig"
  log "not WSL — nothing to do"
fi

# ── 2. Nix ──────────────────────────────────────────────────────────────────

head1 "Nix"

# The installer writes into a fresh login shell only; export now so the rest of
# THIS script sees nix without the user logging out and back in.
export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"

if command -v nix >/dev/null 2>&1; then
  log "nix $(nix --version 2>/dev/null | awk '{print $3}') already installed"
else
  log "installing Nix (Determinate Systems installer) ..."
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm \
    --extra-conf "max-substitution-jobs = 128" \
    --extra-conf "http-connections = 128"
fi

# shellcheck disable=SC1090  # fixed nix profile paths, not user input
for f in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
         /nix/var/nix/profiles/default/etc/profile.d/nix.sh; do
  [ -e "$f" ] && . "$f"
done
command -v nix >/dev/null 2>&1 || die "nix not on PATH after install — open a new terminal and re-run"

# ── 3. devenv ───────────────────────────────────────────────────────────────

head1 "devenv"

if command -v devenv >/dev/null 2>&1; then
  log "devenv $(devenv --version | awk '{print $2}') already installed"
else
  log "installing devenv ..."
  nix profile install nixpkgs#devenv
fi
command -v devenv >/dev/null 2>&1 || die "devenv not on PATH after install — open a new terminal and re-run"

# ── 4. fetch the repo ───────────────────────────────────────────────────────

head1 "repo"

if [ -f "$DEST/devenv.nix" ] || [ -d "$DEST/.git" ]; then
  log "$DEST already present — skipping fetch"
else
  # Probe reachability BEFORE committing to a fetch path. A private or
  # not-yet-created repo makes git fail with "could not read Username", which
  # is cryptic enough to cost a student an hour, and the tarball path just
  # 404s. Either way, say what is wrong instead of letting git guess.
  TARBALL="https://github.com/${REPO_OWNER}/ioi-env/archive/refs/heads/${BRANCH}.tar.gz"
  if ! curl -fsSL -o /dev/null "$TARBALL" 2>/dev/null; then
    if [ -z "${GITHUB_TOKEN:-}" ]; then
      die "cannot reach $TARBALL
  That is what a PRIVATE (or not-yet-created) repository looks like. Pick one:

  1. install git and clone with your own access, then re-run:
       sudo apt install -y git
       git clone $REPO $DEST

  2. private repo + token:
       GITHUB_TOKEN=ghp_xxx curl -fsSL <this script> | bash

  3. copy the directory in yourself, then re-run:
       IOI_ENV_DIR=/path/to/ioi-env curl -fsSL <this script> | bash"
    fi
    # A token is set: the anonymous probe failed but the token may reach it, so
    # fall through and let git try.
    log "anonymous tarball unreachable, but GITHUB_TOKEN is set — trying git clone"
  fi

  if command -v git >/dev/null 2>&1; then
    log "git clone $REPO -> $DEST"
    if [ -n "${GITHUB_TOKEN:-}" ]; then
      git clone --branch "$BRANCH" "https://x-access-token:${GITHUB_TOKEN}@${REPO#https://}" "$DEST"
    else
      git clone --branch "$BRANCH" "$REPO" "$DEST"
    fi
  else
    # No git on a fresh WSL box: the anonymous tarball is the only path, and it
    # only works for a PUBLIC repo.
    log "downloading $BRANCH tarball -> $DEST"
    mkdir -p "$DEST"
    TMP_TAR=$(mktemp /tmp/ioi-env.XXXXXX.tar.gz)
    trap 'rm -f "$TMP_TAR"' EXIT
    curl -fsSL -o "$TMP_TAR" "$TARBALL"
    tar xzf "$TMP_TAR" --strip-components=1 -C "$DEST"
  fi
fi

[ -f "$DEST/devenv.nix" ] || die "$DEST has no devenv.nix — fetch failed"

# ── 5. vimrc ─────────────────────────────────────────────────────────────────

head1 "vimrc"

if [ -f "$HOME/.vimrc" ]; then
  log "$HOME/.vimrc already exists — leaving it alone"
  log "the shipped one is at $DEST/deploy/vimrc (diff them if you're curious)"
elif [ -f "$DEST/deploy/vimrc" ]; then
  cp "$DEST/deploy/vimrc" "$HOME/.vimrc"
  log "installed contest-grade ~/.vimrc (no plugins; F5 = g++ -O2 -std=c++17 -Wall)"
else
  log "no deploy/vimrc in $DEST — skipped"
fi

# ── 6. the steps that need a password ───────────────────────────────────────

head1 "remaining host steps (need sudo — run once)"

cat <<'EOS'
  WSL appends the whole Windows PATH into Linux, dragging find.exe / sort.exe
  along with it. Anything you type that collides with a Windows command
  silently runs the Windows one. Turn it off, then restart WSL:

    sudo tee /etc/wsl.conf >/dev/null <<'EOF'
    [boot]
    systemd=true

    [interop]
    appendWindowsPath=false

    [automount]
    enabled=true
    options="metadata,umask=22,fmask=11"
    EOF

  And make the clock UTC+8 so contest start times and log timestamps line up:

    sudo ln -sf /usr/share/zoneinfo/Asia/Taipei /etc/localtime
    echo "Asia/Taipei" | sudo tee /etc/timezone

  Then, from cmd:  wsl --shutdown   and reopen.
EOS

# ── 7. enter the shell ───────────────────────────────────────────────────────

head1 "entering devenv shell"

cd "$DEST"
devenv allow

if [ "$NO_SHELL" = "1" ]; then
  log "IOI_ENV_NO_SHELL=1 — stopping before the shell (run 'devenv shell' here to continue)"
  exit 0
fi

# First entry downloads nixpkgs plus every package; on a cold cache this is the
# slow part, so say so instead of looking hung.
log "first-time build can take several minutes — it is downloading, not stuck"
log ""

# `curl | bash` leaves stdin on the script pipe, which is already at EOF by the
# time we get here, so an interactive shell would exit instantly. Attach the
# real terminal when one exists; otherwise tell the user how to get in.
if [ -e /dev/tty ] && [ -r /dev/tty ]; then
  exec devenv shell < /dev/tty
else
  log "no controlling terminal — run this to enter the shell:"
  log "    cd $DEST && devenv shell"
fi
