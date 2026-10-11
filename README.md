# ioi-env

One command to a competition-matching compiler.

```bash
curl -fsSL https://raw.githubusercontent.com/eouzoe/ioi-env/main/scripts/start.sh | bash
```

## What you get

Pinned to the competition spec (臺北市 115 學年度資訊學科能力競賽實施計畫,
附件一第 10 點):

| | Spec | Where it comes from |
|---|---|---|
| Compiler | gcc/g++ **13.3.0** | nixpkgs pin — the one thing that must not drift |
| Language | C++17 | the compiler above |
| Editor | vim **9.1** | already in the WSL image (9.1.0016, exactly the spec) |

Everything else you need comes with the WSL image and is **not** re-downloaded:
`vim 9.1`, `python3`, `git`, `diffutils`, `time`. `gcc`/`g++` is the only thing
Ubuntu 24.04's WSL rootfs does not ship at all, so it is the only thing installed
— and installing it means pinning it, because Ubuntu LTS `-updates` will move
gcc 13.x under you (`apt install g++` gives 13.3.0 today and 13.4.0 later).

`just check-env` fails loudly if the pin drifts, including a guard that
`<print>` (C++23) must **not** compile — the one drift that would silently
teach code the judge rejects.

## It writes one file

`~/.vimrc`, and only if you do not already have one. Yours is never touched.

It deliberately writes **nothing else on your machine**:

- **no `.wslconfig`.** That file is yours, tuned for your RAM and CPU, and a
  script cannot know your numbers. Writing one, or editing yours, is how you end
  up with a machine that cannot boot Windows.
- **no `/etc/wsl.conf`**, no `appendWindowsPath=false`, no timezone change,
  no `apt`, no background service.

The compiler lives in a Nix store outside your filesystem; removing the project
directory is the entire uninstall.

## Usage

```bash
just bootstrap      # one-time: installs ~/.vimrc if absent
just check-env      # compiler pin + std-guard
devenv shell        # enter the toolchain
```

vim keys: `F5` compile+run, `F6` with `< input.txt`, `F7` syntax-only,
`F8` sanitizers, `F9` `/usr/bin/time -v`.

`F8` runs under `setarch -R`, which is load-bearing: Nix's ASan runtime
intermittently fails to mmap under high-entropy ASLR (measured 6/30 silent
SEGVs). `just check-asan` runs it 20 times and fails if it is not stable.

## About the OS version

The spec names **Ubuntu 24.04.2**. `wsl --install -d Ubuntu-24.04` installs
whatever Canonical last published, which is 24.04.5 today — there is no version
selector on the Store appx, no 24.04.2 snapshot on
`cloud-images.ubuntu.com/wsl/releases/noble/` (only `20240423/` = 24.04.0 and
`current/`), and no version flag in Canonical's own tooling.

It does not matter: the judge compiles with *its* gcc 13.3.0, and ours is
Nix-pinned rather than taken from the distro.

## Layout

```
scripts/start.sh       Nix + devenv + fetch this repo, then hand to `just`
Justfile               all setup and verification recipes
deploy/vimrc           contest-grade vimrc → ~/.vimrc
devenv.nix             gcc13 pin
devenv.yaml            nixpkgs 25.05 pin, shell: bash
lefthook.yml           pre-push checks (git)
scripts/ci-wsl-env.sh  CI-only: devenv on PATH inside a fresh WSL step
.github/workflows/ci.yml
```

## Maintainer

Not for students — they never push.

```bash
cp devenv.local.nix.example devenv.local.nix   # lefthook, shellcheck, actionlint, yamllint
just hooks                                     # install the git hooks
just jj-setup                                  # make `jj push` run them first
```

`lefthook.yml` runs the same `just` recipes CI does. `jj git push` does not run
git hooks, so `just jj-setup` adds a jj alias that runs the checks and then
pushes.

## CI

| Job | What it proves |
|---|---|
| `lint` | shellcheck + vimrc parse + **actionlint** |
| `wsl` | blank Windows → install WSL Ubuntu 24.04 → run the student command **inside WSL** |
| `oneliner-remote` | the literal `curl \| bash` from the README, against published `main` |

The `wsl` job is the one that matters. It also covers the paths a student's
real machine takes and a fresh runner never does: a pre-existing `~/.vimrc`
(planted sentinel must survive byte-for-byte), `start.sh` fetching the repo
itself inside WSL, the whole path being re-runnable, and an assertion that
nothing outside `~/.vimrc` was modified on the host.
