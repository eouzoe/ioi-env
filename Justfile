_default:
    @just --list

# ══════════════════════════════════════════════════════════════════
# student-facing
# ══════════════════════════════════════════════════════════════════

# one-time host setup: vimrc + Windows-side .wslconfig
bootstrap:
    #!/usr/bin/env bash
    set -uo pipefail
    root="$(cd "$(dirname "{{justfile()}}")" && pwd)"
    fail=0

    echo "── vimrc ──"
    if [ -f "$HOME/.vimrc" ]; then
      echo "  $HOME/.vimrc already exists — leaving it alone"
      echo "  (shipped one is at $root/deploy/vimrc)"
    else
      cp "$root/deploy/vimrc" "$HOME/.vimrc"
      echo "  installed $HOME/.vimrc — no plugins, F5 = g++ -O2 -std=c++17 -Wall"
    fi

    echo "── .wslconfig ──"
    win_profile=""
    if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null || [ -d /mnt/c/Windows ]; then
        if [ -x /mnt/c/Windows/System32/cmd.exe ]; then
            u=$(/mnt/c/Windows/System32/cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r' || true)
            [ -n "$u" ] && [ -d "/mnt/c/Users/$u" ] && win_profile="/mnt/c/Users/$u"
        fi
    fi

    if [ -z "$win_profile" ]; then
        echo "  not WSL, or Windows profile not found — nothing to do"
    elif [ -f "$win_profile/.wslconfig" ]; then
        echo "  $win_profile/.wslconfig already exists — leaving it alone"
        echo "  to get the pinned values, merge in: [wsl2] memory=8GB processors=4 swap=0"
    else
        # printf, not a heredoc: heredoc bodies inside a just recipe inherit the
        # recipe's indentation and WSL wants a clean INI. Written from Linux so
        # there is no BOM and no CRLF either — either one makes WSL silently
        # ignore the ENTIRE file.
        printf '[wsl2]\nmemory=8GB\nprocessors=4\nswap=0\nlocalhostForwarding=true\n' \
            > "$win_profile/.wslconfig"
        echo "  wrote $win_profile/.wslconfig"
        echo "  takes effect after: wsl --shutdown  (run from cmd, then reopen)"
    fi

    echo ""
    echo "── remaining steps need sudo (run once) ──"
    cat <<'EOS'
    WSL appends the whole Windows PATH into Linux, dragging find.exe / sort.exe
    along. Anything you type that collides with a Windows command silently runs
    the Windows one. Turn it off, then restart WSL:

        sudo tee /etc/wsl.conf >/dev/null <<'WEOF'
        [boot]
        systemd=true

        [interop]
        appendWindowsPath=false

        [automount]
        enabled=true
        options="metadata,umask=22,fmask=11"
        WEOF

    And make the clock UTC+8 so contest start times line up:

        sudo ln -sf /usr/share/zoneinfo/Asia/Taipei /etc/localtime
        echo "Asia/Taipei" | sudo tee /etc/timezone

    Then, from cmd:  wsl --shutdown   and reopen.
    EOS

    echo ""
    echo "bootstrap done. 下一步: just check-env"
    [ "$fail" = 0 ]

# enter the student shell
shell:
    devenv shell

# run every verification recipe (what the pre-push hook also runs)
prepush:
    just lint check-env check-compile check-vimrc check-asan

# jj users run this before pushing, because `jj git push` bypasses git hooks
prepush-jj: prepush
    #!/usr/bin/env bash
    echo ""
    echo "  local checks passed — safe to run:"
    echo "      jj git push --bookmark main"

# update the pinned nixpkgs input (only when you mean to)
update:
    devenv update

# ══════════════════════════════════════════════════════════════════
# verification — the same recipes CI and the pre-push hook run,
# so there is exactly one copy of every rule
# ══════════════════════════════════════════════════════════════════

# versions, missing tools, and the std-guard
check-env:
    #!/usr/bin/env bash
    set -uo pipefail
    fail=0
    chk() { # name actual want-prefix
      if printf '%s' "$2" | grep -q "^$3"; then
        printf '  %-10s %-16s ok\n' "$1" "$2"
      else
        printf '  %-10s %-16s WRONG (want %s*)\n' "$1" "$2" "$3"
        fail=1
      fi
    }

    echo "ioi-env — competition alignment"
    echo "  spec: Ubuntu 24.04.2 · gcc/g++ 13.3.0 · C++17 · vim 9.1"
    chk g++  "$(g++ -dumpversion 2>/dev/null || echo missing)" "13.3"
    chk vim  "$(vim --version 2>/dev/null | head -1 | awk '{print $5}' || echo missing)" "9.1"
    chk make "$(make --version 2>/dev/null | head -1 | awk '{print $3}' || echo missing)" "4"
    for c in gdb python3 diff timeout; do
      if command -v "$c" >/dev/null 2>&1; then
        printf '  %-10s ok\n' "$c"
      else
        printf '  %-10s MISSING\n' "$c"; fail=1
      fi
    done
    # `time` is deliberately NOT in that list. /usr/bin/time lives in the nix
    # `time` package, but `command -v time` also finds bash's builtin, so the
    # check would pass on a machine where the real binary is missing — a check
    # that cannot fail is worse than no check. check-compile uses it by absolute
    # path instead.

    t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
    printf '#include <print>\nint main(){ std::println("x"); }\n' > "$t/cpp23.cpp"
    if g++ -O2 -std=c++17 "$t/cpp23.cpp" -o "$t/cpp23" 2>/dev/null; then
      printf '  %-10s FAIL — <print> compiled: pin drifted to C++23\n' "std-guard"
      fail=1
    else
      printf '  %-10s ok (C++23 rejected, as the judge does)\n' "std-guard"
    fi

    if [ "$fail" = 0 ]; then echo "  all good"; else echo "  ENV DRIFTED — re-check devenv.yaml / devenv.nix"; exit 1; fi

# C++17 compiles and runs; C++23 is rejected
check-compile:
    #!/usr/bin/env bash
    set -euo pipefail
    t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
    cat > "$t/a.cpp" <<'CPP'
    #include <iostream>
    #include <vector>
    int main()
    {
        int n;
        std::cin >> n;
        std::vector<int> v(n);
        for (auto& x : v) std::cin >> x;
        long long s = 0;
        for (int x : v) s += x;
        std::cout << s << '\n';
    }
    CPP
    g++ -O2 -std=c++17 -Wall -Wextra "$t/a.cpp" -o "$t/a"
    [ "$(echo '3 1 2 3' | "$t/a")" = "6" ] && echo "  C++17 compile+run OK"

    printf '#include <print>\nint main(){ std::println("x"); }\n' > "$t/b.cpp"
    if g++ -O2 -std=c++17 "$t/b.cpp" -o "$t/b" 2>/dev/null; then
      echo "  FAIL: <print> compiled — compiler drifted past C++17"; exit 1
    fi
    echo "  C++23 correctly rejected OK"

# sanitizers must be deterministic, or students chase bugs that are not theirs
check-asan:
    #!/usr/bin/env bash
    set -euo pipefail
    t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
    cat > "$t/a.cpp" <<'CPP'
    #include <iostream>
    int main() { int n; std::cin >> n; std::cout << n * 2 << '\n'; }
    CPP
    g++ -g -O1 -std=c++17 -fsanitize=address,undefined "$t/a.cpp" -o "$t/a_san"
    # setarch -R is load-bearing: nix's ASan runtime intermittently fails to
    # mmap under high-entropy ASLR (measured 6/30 silent SEGVs, no ASan output).
    bad=0
    for _ in $(seq 1 20); do
      [ "$(echo 5 | setarch "$(uname -m)" -R "$t/a_san" 2>/dev/null)" = "10" ] || bad=$((bad+1))
    done
    if [ "$bad" -eq 0 ]; then
      echo "  ASan deterministic 20/20 OK"
    else
      echo "  ASan failed $bad/20 runs"; exit 1
    fi

# the shipped vimrc must parse cleanly under the pinned vim
check-vimrc:
    #!/usr/bin/env bash
    set -euo pipefail
    vim -Nu deploy/vimrc -n -es -c 'qa!' && echo "  deploy/vimrc OK"
    if [ -f "$HOME/.vimrc" ]; then
      vim -Nu "$HOME/.vimrc" -n -es -c 'qa!' && echo "  ~/.vimrc OK"
    else
      echo "  ~/.vimrc not installed yet (run: just bootstrap)"
    fi
    grep -q 'std=c++17' deploy/vimrc || { echo "  FAIL: vimrc no longer targets C++17"; exit 1; }
    grep -q 'setarch' deploy/vimrc || { echo "  FAIL: vimrc dropped the setarch -R guard"; exit 1; }

# static lint of the shell scripts and the workflow (skips cleanly if absent)
lint:
    #!/usr/bin/env bash
    set -uo pipefail
    if command -v shellcheck >/dev/null 2>&1; then
      # -s sh: POSIX sh, not bash. The script runs under dash on Ubuntu, so
      # bash-only constructs would pass here and die on a student's machine.
      # Both scripts, not just start.sh — ci-wsl-env.sh is shell code too and
      # used to go unchecked.
      shellcheck -s sh scripts/start.sh scripts/ci-wsl-env.sh && echo "  shell scripts lint OK"
    else
      echo "  shellcheck not installed — skipped (devenv.local.nix adds it)"
    fi
    if command -v yamllint >/dev/null 2>&1; then
      # -d relaxed: the default config treats long lines as errors, which is
      # wrong for a workflow whose comments carry the reasoning.
      yamllint -d relaxed -d "{extends: relaxed, rules: {line-length: disable}}" \
        .github/workflows/ci.yml && echo "  ci.yml yamllint OK"
    else
      echo "  yamllint not installed — skipped (devenv.local.nix adds it)"
    fi
    if command -v actionlint >/dev/null 2>&1; then
      # actionlint carries the real GitHub Actions schema plus semantic checks
      # YAML parsing cannot do. It earned its place immediately: it caught a
      # job-level `env:` using the `runner` context (only
      # github/inputs/matrix/needs/secrets/strategy/vars are legal there) and
      # an unknown runner label — either one makes the whole workflow fail to
      # parse with zero jobs created, which surfaces as "workflow file issue"
      # and tells you nothing about which line is wrong.
      actionlint .github/workflows/ci.yml && echo "  ci.yml actionlint OK"
    else
      echo "  actionlint not installed — skipped (devenv.local.nix adds it)"
    fi

# run every verification recipe (what the pre-push hook also runs)
verify: lint check-vimrc check-env check-compile check-asan
    @echo "  all verification passed"

# ══════════════════════════════════════════════════════════════════
# maintainer — one-time local setup, not part of the student path
# ══════════════════════════════════════════════════════════════════

# install the git hooks (lefthook, from devenv.local.nix)
hooks:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f devenv.local.nix ]; then
      cp devenv.local.nix.example devenv.local.nix
      echo "  created devenv.local.nix (lefthook + shellcheck + actionlint + yamllint)"
    fi
    devenv shell --no-tui -- lefthook install

# teach this jj repo to run the pre-push checks before `jj git push`.
# `jj git push` does not run git hooks, so without this a push silently skips
# them. The alias lands in .jj/repo/config.toml — local only — which is why it
# is set per clone instead of committed.
jj-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v jj >/dev/null 2>&1 || { echo "  jj not installed"; exit 1; }
    jj config set --repo aliases.push \
      '["util", "exec", "--", "bash", "-c", "devenv shell --no-tui -- lefthook run pre-push && jj git push \"$@\"", ""]'
    echo "  jj push now runs the pre-push checks first"

# both hook paths: lefthook directly, and the jj alias's check step
check-hooks: hooks jj-setup
    #!/usr/bin/env bash
    set -euo pipefail
    devenv shell --no-tui -- lefthook run pre-push
