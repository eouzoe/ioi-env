_default:
    @just --list

# ══════════════════════════════════════════════════════════════════
# student-facing
# ══════════════════════════════════════════════════════════════════

# 一次性：裝 vimrc。這是本專案**唯一**會寫進你家目錄的檔案，
# 而且只在你沒有的時候寫；已有的絕對不動。
bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail
    root="$(cd "$(dirname "{{justfile()}}")" && pwd)"

    if [ -f "$HOME/.vimrc" ]; then
      echo "  ~/.vimrc already exists — leaving it alone"
      echo "  (shipped one: $root/deploy/vimrc)"
    else
      cp "$root/deploy/vimrc" "$HOME/.vimrc"
      echo "  installed ~/.vimrc — no plugins, F5 = g++ -O2 -std=c++17 -Wall"
    fi

# enter the toolchain
shell:
    devenv shell

# run every verification recipe
prepush: lint check-vimrc check-env check-compile check-asan
    @echo "  all verification passed"

# jj users run this before pushing, because `jj git push` bypasses git hooks
prepush-jj: prepush
    #!/usr/bin/env bash
    echo ""
    echo "  local checks passed — safe to run:"
    echo "      jj git push --bookmark main"

# run every verification recipe
verify: prepush
    @echo "  all verification passed"

# update the pinned nixpkgs input (only when you mean to)
update:
    devenv update

# ══════════════════════════════════════════════════════════════════
# verification — CI 和 pre-push hook 跑同一份，規則只有一處
# ══════════════════════════════════════════════════════════════════

# 編譯器釘子 + 遺失工具
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
    echo "  gcc/g++ 13.3.0 · C++17 · vim 9.1  (compiler nix-pinned, rest from the distro)"
    chk g++ "$(g++ -dumpversion 2>/dev/null || echo missing)" "13.3"
    chk vim "$(vim --version 2>/dev/null | head -1 | awk '{print $5}' || echo missing)" "9.1"

    for c in python3 diff; do
      if command -v "$c" >/dev/null 2>&1; then
        printf '  %-10s ok\n' "$c"
      else
        printf '  %-10s MISSING\n' "$c"; fail=1
      fi
    done

    # 真正的守門員。<print> 是 C++23：judge 的 gcc 13.3 不接受，我們也不准接受。
    # 它一旦編過就代表釘子漂了，學生在練 judge 會拒收的東西。
    t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
    printf '#include <print>\nint main(){ std::println("x"); }\n' > "$t/cpp23.cpp"
    if g++ -O2 -std=c++17 "$t/cpp23.cpp" -o "$t/cpp23" 2>/dev/null; then
      printf '  %-10s FAIL — <print> compiled: pin drifted to C++23\n' "std-guard"
      fail=1
    else
      printf '  %-10s ok (C++23 rejected, as the judge does)\n' "std-guard"
    fi

    if [ "$fail" = 0 ]; then echo "  all good"; else echo "  ENV DRIFTED — re-check devenv.yaml / devenv.nix"; exit 1; fi

# C++17 編得過也跑得動；C++23 必須被拒
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

# sanitizer 必須穩定，否則學生會去追不是自己的 bug
check-asan:
    #!/usr/bin/env bash
    set -euo pipefail
    t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
    cat > "$t/a.cpp" <<'CPP'
    #include <iostream>
    int main() { int n; std::cin >> n; std::cout << n * 2 << '\n'; }
    CPP
    g++ -g -O1 -std=c++17 -fsanitize=address,undefined "$t/a.cpp" -o "$t/a_san"
    # setarch -R 是必要的：nix 的 ASan runtime 在高 ASLR 位址下偶發 mmap 失敗，
    # 實測 30 次有 6 次靜默 SEGV（沒有任何 ASan 訊息，輸出是空的）。
    bad=0
    for _ in $(seq 1 20); do
      [ "$(echo 5 | setarch "$(uname -m)" -R "$t/a_san" 2>/dev/null)" = "10" ] || bad=$((bad+1))
    done
    if [ "$bad" -eq 0 ]; then
      echo "  ASan deterministic 20/20 OK"
    else
      echo "  ASan failed $bad/20 runs"; exit 1
    fi

# 出貨的 vimrc 必須能在釘住的 vim 下乾淨載入
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

# 靜態檢查 shell 腳本與 workflow（工具不在就乾淨跳過）
lint:
    #!/usr/bin/env bash
    set -uo pipefail
    if command -v shellcheck >/dev/null 2>&1; then
      # -s sh：POSIX sh，不是 bash。腳本在 Ubuntu 上用 dash 跑，bash-only 寫法
      # 在這裡會過、在學生機器上會死。
      shellcheck -s sh scripts/start.sh scripts/ci-wsl-env.sh && echo "  shell scripts lint OK"
    else
      echo "  shellcheck not installed — skipped (devenv.local.nix adds it)"
    fi
    if command -v yamllint >/dev/null 2>&1; then
      # -d relaxed：預設設定把長行當錯誤，但這個 workflow 的論證都寫在註解裡。
      yamllint -d relaxed -d "{extends: relaxed, rules: {line-length: disable}}" \
        .github/workflows/ci.yml && echo "  ci.yml yamllint OK"
    else
      echo "  yamllint not installed — skipped"
    fi
    if command -v actionlint >/dev/null 2>&1; then
      # actionlint 帶真的 GitHub Actions schema + 語意檢查，YAML 解析做不到的
      # 它做得到：它抓過 job-level env 用了 runner context、job name 含 ": "、
      # step 混用 run: 與 parallel: —— 任一個都讓整個 workflow 零 job 失敗，
      # 而 GitHub 只告訴你 "workflow file issue"，不給行號。
      actionlint .github/workflows/ci.yml && echo "  ci.yml actionlint OK"
    else
      echo "  actionlint not installed — skipped (devenv.local.nix adds it)"
    fi

# ══════════════════════════════════════════════════════════════════
# maintainer — 學生不需要
# ══════════════════════════════════════════════════════════════════

# 安裝 git hooks（lefthook，來自 devenv.local.nix）
hooks:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f devenv.local.nix ]; then
      cp devenv.local.nix.example devenv.local.nix
      echo "  created devenv.local.nix (lefthook + shellcheck + actionlint + yamllint)"
    fi
    devenv shell --no-tui -- lefthook install

# 讓這個 jj repo 在 `jj git push` 前先跑檢查。
# `jj git push` 不跑 git hooks，沒有這個別名的話推送會整個跳過驗證。
jj-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v jj >/dev/null 2>&1 || { echo "  jj not installed"; exit 1; }
    jj config set --repo aliases.push \
      '["util", "exec", "--", "bash", "-c", "devenv shell --no-tui -- lefthook run pre-push && jj git push \"$@\"", ""]'
    echo "  jj push now runs the pre-push checks first"

# 兩條 hook 路徑都驗一次
check-hooks: hooks jj-setup
    #!/usr/bin/env bash
    set -euo pipefail
    devenv shell --no-tui -- lefthook run pre-push
