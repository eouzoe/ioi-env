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
| Compiler | gcc/g++ **13.3.0** | `gcc13` = 13.3.0 |
| Language | C++17 | `-std=c++17` |
| Editor | vim **9.1** | `vim` = 9.1.1336 |

The compiler and editor pins are **exact**, not approximate — nixpkgs 25.05
happens to ship exactly those versions (rolling gives 13.4.0 / vim 9.2, and
25.11 already moved gcc13). `devenv.yaml` names the release so the choice is
deliberate and reviewable.

`just check-env` fails loudly if any of it drifts, including a guard that
`<print>` (C++23) must **not** compile — the one drift that would silently
teach code the judge rejects.

### About the OS version — what the spec says vs. what you will get

The spec names **Ubuntu 24.04.2**. A student who runs
`wsl --install -d Ubuntu-24.04` gets whatever Canonical last published to the
Store, which today is 24.04**.5** — not .2.

That is not a shortcoming of this setup, it is not avoidable:

- The Store's `Ubuntu-24.04` appx has no version selector. There is no
  `wsl --install -d Ubuntu-24.04.2`.
- `cloud-images.ubuntu.com/wsl/releases/noble/` publishes exactly two images
  per series: the original dated build (`20240423/`, i.e. 24.04.**0**) and
  `current/`. There is no .2 snapshot.
- Canonical's own `release-info` tooling (used by their `download-rootfs`
  GitHub action) has `--rootfs <arch>` and no version flag either, so the
  official path cannot pin a point release.

**And it does not matter.** The judge compiles with *its* gcc 13.3.0. What has
to match is the compiler, and the compiler here comes from the nixpkgs pin —
not from apt, not from the distro. Same for vim. Point releases within a series
carry the same kernel ABI and the same package set for anything this
environment uses, so the only thing that would change by chasing 24.04.2 is the
`lsb_release` string.

So: install with `wsl --install -d Ubuntu-24.04`, accept whatever point
release it gives, and let `just check-env` guard the versions that actually
affect submissions.

## Layout

```
scripts/start.sh       bootstrap: Nix + devenv + fetch this repo, then hands to `just`
Justfile               all setup and verification recipes
deploy/vimrc           contest-grade vimrc → installed to ~/.vimrc
devenv.nix             pinned toolchain
devenv.yaml            nixpkgs 25.05 pin, shell: bash
lefthook.yml           pre-push checks (git)
scripts/ci-wsl-env.sh  CI-only: puts devenv on PATH inside a fresh WSL step
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
cp devenv.local.nix.example devenv.local.nix   # lefthook, shellcheck, actionlint, yamllint
just hooks                                     # install the git hooks
just jj-setup                                  # make `jj push` run them first
```

`lefthook.yml` runs the same `just` recipes CI does. `jj git push` does not run
git hooks, so `just jj-setup` adds a jj alias that runs the checks and then
pushes; without it, a jj push skips validation entirely.

## CI

Three jobs, all green:

| Job | What it proves |
|---|---|
| `lint` | shellcheck + vimrc parse + **actionlint** — the fast one, and the one that catches workflow mistakes before the slow jobs run |
| `wsl` | blank Windows → install WSL → install Ubuntu 24.04 → run the student's command **inside WSL** |
| `oneliner-remote` | the literal `curl \| bash` from the README, against published `main` |

The `wsl` job is the one that matters, because it is the only place the
WSL-only code is exercised: the `IS_WSL` branch, the `/mnt/c` + `cmd.exe`
interop that locates the Windows profile, the `.wslconfig` write to the Windows
filesystem, and the no-TTY fallback when `/dev/tty` cannot be opened. It also
runs `start.sh` a second time, which is what proves the whole path is
idempotent.
