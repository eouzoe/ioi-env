# ioi-env

One command to a competition-matching development environment.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/eouzoe/ioi-env/main/scripts/start.sh | bash
```

## What you get

Pinned to the competition spec (Ubuntu 24.04 + gcc 13.x + C++17 + vim 9.x),
installed reproducibly via Nix so the compiler version cannot drift.

| Tool | Version | Why |
|---|---|---|
| `g++` | 13.x | judge uses 13.3.0; nixpkgs' default `gcc` is 15.3.0 and would let you practice C++23 the judge rejects |
| `vim` | 9.x | no plugins — the contest machines have none |
| `gdb`, `make`, `python3`, `diffutils`, `time` | — | debugging, stress-testing, timing |

## Layout

```
scripts/start.sh   the bootstrap
deploy/vimrc       contest-grade vimrc, installed to ~/.vimrc
devenv.nix         the pinned toolchain + `just check-env` verify task
.github/workflows/ci.yml   parallel CI that runs start.sh on clean runners
```

## Verify

```bash
just check-env     # fails loudly if any version drifted
```

## Notes

- `devenv.yaml` pins `shell: bash`, because the contest environment is bash.
- Sanitizer runs go through `setarch -R`: nix's ASan runtime intermittently
  fails to mmap under high-entropy ASLR (measured 6/30 silent SEGVs).
