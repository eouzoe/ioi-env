# ioi-env

One command to a competition-matching development environment.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/eouzoe/ioi-env/main/scripts/start.sh | bash
```

## What you get

Pinned to the competition spec (臺北市 115 學年度資訊學科能力競賽實施計畫,
附件一第 10 點) via nixpkgs 25.05:

| | Spec | Here |
|---|---|---|
| OS | Ubuntu 24.04.2 | WSL Ubuntu 24.04 |
| Compiler | gcc/g++ **13.3.0** | `gcc13` = 13.3.0 |
| Language | C++17 | `-std=c++17` |
| Editor | vim **9.1** | `vim` = 9.1.1336 |

The pin is exact, not approximate — nixpkgs 25.05 happens to ship exactly
those versions (rolling gives 13.4.0 / vim 9.2, and 25.11 already moved gcc13).
`devenv.yaml` names the release so the choice is deliberate and reviewable.

`just check-env` fails loudly if any of it drifts, including a guard that
`<print>` (C++23) must **not** compile — the one drift that would silently
teach code the judge rejects.

## Layout

```
scripts/start.sh   bootstrap: Nix + devenv + fetch this repo, then hands to `just`
Justfile           all setup and verification recipes
deploy/vimrc       contest-grade vimrc → installed to ~/.vimrc
devenv.nix         pinned toolchain
devenv.yaml        nixpkgs 25.05 pin, shell: bash
lefthook.yml       pre-push checks (git)
.github/workflows/ci.yml
```

`start.sh` does only the three things it must — install Nix, install devenv,
fetch the repo that contains the Justfile. Everything else is a `just` recipe,
so the student, CI, and the pre-push hook run identical code.

## Usage

```bash
just bootstrap      # one-time: vimrc + .wslconfig (prints the sudo-only steps)
just check-env      # versions + std-guard
just verify         # everything
devenv shell        # enter the toolchain
```

vim keys: `F5` compile+run, `F6` with `< input.txt`, `F7` syntax-only,
`F8` sanitizers, `F9` `/usr/bin/time -v`.

`F8` runs under `setarch -R`, which is load-bearing: nix's ASan runtime
intermittently fails to mmap under high-entropy ASLR (measured 6/30 silent
SEGVs). `just check-asan` runs it 20 times and fails if it is not stable.

## Maintainer

Not for students — they never push.

```bash
cp devenv.local.nix.example devenv.local.nix   # lefthook, shellcheck, yamllint
just hooks                                     # install the git hooks
just jj-setup                                  # make `jj push` run them first
```

`lefthook.yml` runs the same `just` recipes CI does. `jj git push` does not run
git hooks, so `just jj-setup` adds a jj alias that runs the checks and then
pushes; without it, a jj push skips validation entirely.
