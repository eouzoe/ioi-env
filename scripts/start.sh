#!/usr/bin/env sh
# ioi-env — student one-command bootstrap.
#
# Targets the competition environment (Ubuntu 24.04.2 + gcc/g++ 13.3.0 + C++17
# + vim 9.1) and works on any Linux, including WSL Ubuntu.
#
# Usage (the one line a student runs):
#   curl -fsSL https://raw.githubusercontent.com/<owner>/ioi-env/main/scripts/start.sh | bash
#
# This script deliberately does as little as possible: its whole job is to get
# Nix, devenv, and this repo onto the machine, then hand off to `just`. Every
# piece of actual setup — vimrc, .wslconfig, host steps, verification — lives in
# the Justfile, which means CI, the pre-push hook, and the student all run the
# exact same code. Only three things genuinely cannot live there: installing
# Nix, installing devenv, and fetching the repo that contains the Justfile.
#
# Overridable via env:
#   IOI_ENV_REPO        repo to clone (default: the one hosting this script)
#   IOI_ENV_DIR         where to put it (default: ~/ioi-env)
#   IOI_ENV_BRANCH      branch to fetch (default: main)
#   IOI_ENV_NO_SHELL    set to 1 to stop before `devenv shell` (for CI)
#   GITHUB_TOKEN        only needed for a private repo; public repo: leave empty

set -eu

REPO_OWNER="${IOI_ENV_OWNER:-eouzoe}"
REPO="${IOI_ENV_REPO:-https://github.com/${REPO_OWNER}/ioi-env}"
BRANCH="${IOI_ENV_BRANCH:-main}"
DEST="${IOI_ENV_DIR:-$HOME/ioi-env}"
NO_SHELL="${IOI_ENV_NO_SHELL:-0}"

log()   { printf '  %s\n' "$1"; }
head1() { printf '\n── %s ──\n' "$1"; }
die()   { printf '\nerror: %s\n' "$1" >&2; exit 1; }

# ── preflight ───────────────────────────────────────────────────────────────

command -v curl >/dev/null 2>&1 || die "curl is required (WSL Ubuntu ships it; else: sudo apt install curl)"
command -v tar  >/dev/null 2>&1 || die "tar is required (WSL Ubuntu ships it)"

printf '\n  ioi-env — one command to start.\n'
printf '  target: Ubuntu 24.04.2 + gcc/g++ 13.3.0 + C++17 + vim 9.1\n'
# shellcheck disable=SC2016  # literal backticks, not command substitution
printf '          (the competition spec; everything else is delegated to just)\n\n'

# ── 1. Nix ──────────────────────────────────────────────────────────────────

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

# ── 2. devenv ───────────────────────────────────────────────────────────────

head1 "devenv"

if command -v devenv >/dev/null 2>&1; then
  log "devenv $(devenv --version | awk '{print $2}') already installed"
else
  log "installing devenv ..."
  nix profile install nixpkgs#devenv
fi
command -v devenv >/dev/null 2>&1 || die "devenv not on PATH after install — open a new terminal and re-run"

# ── 3. fetch the repo (this brings in the Justfile everything else lives in) ──

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
    # A token is set: the anonymous probe failed but the token may reach it.
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
[ -f "$DEST/Justfile" ]   || die "$DEST has no Justfile — fetch failed"

# ── 4. hand off to `just` ────────────────────────────────────────────────────
# Everything from here — vimrc, .wslconfig, the sudo-only host steps, all the
# verification — is a Justfile recipe. Run the same ones CI runs.

head1 "setup"

cd "$DEST"
devenv allow

# First entry downloads nixpkgs plus every package; on a cold cache this is the
# slow part, so say so instead of looking hung.
log "downloading the pinned toolchain (nixpkgs 25.05) — this is the slow part"
log ""
devenv shell --no-tui -- just bootstrap

head1 "verify"
devenv shell --no-tui -- just check-env

# ── 5. enter the shell ───────────────────────────────────────────────────────

if [ "$NO_SHELL" = "1" ]; then
  head1 "done"
  log "IOI_ENV_NO_SHELL=1 — stopped before the shell"
  log "enter it with:  cd $DEST && devenv shell"
  exit 0
fi

head1 "entering devenv shell"

# `curl | bash` leaves stdin on the script pipe, already at EOF, so an
# interactive shell would exit instantly. Attach the real terminal only when it
# can actually be opened — /dev/tty exists on most WSL boxes but is unopenable
# without a controlling terminal (pipe, cron, CI), and a failed `exec` would
# take the whole script down with a nonzero exit that reads as "install failed".
if [ -e /dev/tty ] && : < /dev/tty 2>/dev/null; then
  exec devenv shell < /dev/tty
else
  log "no usable terminal — enter the shell with:"
  log "    cd $DEST && devenv shell"
fi
