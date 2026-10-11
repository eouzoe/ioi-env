#!/usr/bin/env sh
# CI-only helper: put devenv's own tools on PATH for a step running inside WSL.
#
# Why this exists: Ubuntu/WSL's wsl-bash action spawns a fresh NON-login shell
# for every step, so anything a previous step exported is gone. The earlier
# version only sourced the Nix profile (which covers ~/.nix-profile/bin), but the
# packages declared in devenv.nix live in the project's devenv profile at
# .devenv/profile/bin — which is where `just` actually is. Sourcing Nix alone
# left `just` unfindable.
#
# Not used by start.sh — inside the student's flow `devenv shell` sets this up
# itself, and the two never mix.

set -eu

# Nix itself, for `nix`/`devenv` CLI invocations from a bare step.
# shellcheck disable=SC1090  # fixed nix profile paths, not user input
for p in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
         /nix/var/nix/profiles/default/etc/profile.d/nix.sh; do
  [ -e "$p" ] && . "$p"
done

# The devenv profile, which is where the project's packages are linked.
if [ -n "${DEVENV_ROOT:-}" ] && [ -d "$DEVENV_ROOT/.devenv/profile/bin" ]; then
  PATH="$DEVENV_ROOT/.devenv/profile/bin:$PATH"
elif [ -d "$PWD/.devenv/profile/bin" ]; then
  PATH="$PWD/.devenv/profile/bin:$PATH"
fi
export PATH

command -v just >/dev/null 2>&1 || {
  echo "  FAIL: just not on PATH after sourcing the devenv profile" >&2
  exit 1
}
