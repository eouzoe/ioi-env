#!/usr/bin/env sh
# CI-only helper: put devenv on PATH for a step running inside WSL.
#
# Why this exists: Ubuntu/WSL's wsl-bash action spawns a fresh NON-login shell
# for every step, so anything a previous step exported is gone. start.sh runs in
# one shell lifetime and sources the nix profile itself, but the verification
# steps that follow it each need their own. Sourcing this from those steps keeps
# that knowledge in one lintable place instead of copy-pasted into each.
#
# Not used by start.sh — the student path never needs this.
set -eu

# shellcheck disable=SC1090  # fixed nix profile paths, not user input
for p in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
         /nix/var/nix/profiles/default/etc/profile.d/nix.sh; do
  [ -e "$p" ] && . "$p"
done

command -v devenv >/dev/null 2>&1 || {
  echo "  FAIL: devenv not on PATH after sourcing the nix profile" >&2
  exit 1
}
