_default:
    @just --list

# ══════════════════════════════════════════════════════════════════
# 學生用
# ══════════════════════════════════════════════════════════════════

# 一次性：裝 vimrc 與 zshrc。都只在你不存在時裝，已有的絕對不動。
bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail
    root="$(cd "$(dirname "{{justfile()}}")" && pwd)"

    if [ -f "$HOME/.vimrc" ]; then
      echo "  ~/.vimrc already exists — leaving it alone"
      echo "  (shipped one: $root/deploy/vimrc)"
    else
      cp "$root/deploy/vimrc" "$HOME/.vimrc"
      echo "  installed ~/.vimrc"
    fi

    if [ -f "$HOME/.zshrc" ]; then
      echo "  ~/.zshrc already exists — leaving it alone"
      echo "  (shipped one: $root/deploy/zshrc, with oh-my-zsh wired to the devenv profile)"
    else
      cp "$root/deploy/zshrc" "$HOME/.zshrc"
      echo "  installed ~/.zshrc (zsh + oh-my-zsh)"
    fi

    echo ""
    echo "  完成。之後每次進入："
    echo "      cd ~/ioi-env && devenv shell"

# enter the toolchain
shell:
    devenv shell

# 檢查工具鏈版本有沒有漂
check-env:
    #!/usr/bin/env bash
    set -uo pipefail
    fail=0
    chk() {
      if printf '%s' "$2" | grep -q "^$3"; then
        printf '  %-10s %-14s ok\n' "$1" "$2"
      else
        printf '  %-10s %-14s WRONG (want %s*)\n' "$1" "$2" "$3"; fail=1
      fi
    }
    echo "臺北市資訊學科能力競賽 地區複賽 — 本地環境"
    echo "  規格: gcc/g++ 13.3.0 · C++17 · vim 9.1 · Ubuntu 24.04"
    chk g++ "$(g++ -dumpversion 2>/dev/null || echo missing)" "13.3"
    chk vim "$(vim --version 2>/dev/null | head -1 | awk '{print $5}' || echo missing)" "9.1"
    # gdb 版本在 "GNU gdb (GDB) 16.2" 的第 4 欄，且格式會變，所以不數欄位，直接抓版本樣式
    chk gdb "$(gdb --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo missing)" "16"
    for c in zsh make diff python3; do
      if command -v "$c" >/dev/null 2>&1; then printf '  %-10s ok\n' "$c"; else printf '  %-10s MISSING\n' "$c"; fail=1; fi
    done
    [ -d "$DEVENV_PROFILE/share/oh-my-zsh" ] && echo "  oh-my-zsh ok" || { echo "  oh-my-zsh MISSING"; fail=1; }

    # 純度檢查。被咬三次才加的：just 兩次在重寫時被從 packages 移除，而本地照樣
    # 全綠，只有 CI 才炸。原因是 `devenv shell -- just ...` 裡的 just 會從我
    # 外層環境的 PATH 繼承過來，devenv profile 裡沒有也照樣跑得動。
    #
    # 所以判據不是 command -v 解析到哪（那會拿到繼承來的那個），而是
    # DEVENV_PROFILE/bin 底下有沒有這個 binary。just 移除時它就不見，本地立刻紅。
    # g++ 不用這項：它有版本釘子（13.3.0）擋著，而且 gcc-wrapper 的 store path
    # 永遠不會等於 DEVENV_PROFILE/bin 下的 symlink。
    for bin in just; do
      if [ -x "$DEVENV_PROFILE/bin/$bin" ]; then
        printf '  %-10s in devenv profile ok\n' "$bin"
      else
        printf '  %-10s NOT IN devenv profile — leaked from the outer PATH\n' "$bin"
        fail=1
      fi
    done
    if [ "$fail" = 0 ]; then echo "  all good"; else exit 1; fi

# ══════════════════════════════════════════════════════════════════
# maintainer（學生不需要）
# ══════════════════════════════════════════════════════════════════

lint:
    #!/usr/bin/env bash
    set -uo pipefail
    command -v shellcheck >/dev/null 2>&1 && shellcheck -s sh scripts/start.sh && echo "  start.sh lint OK" || echo "  shellcheck skipped"
    command -v actionlint >/dev/null 2>&1 && actionlint .github/workflows/ci.yml && echo "  ci.yml actionlint OK" || echo "  actionlint skipped"

hooks:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f devenv.local.nix ] || cp devenv.local.nix.example devenv.local.nix
    devenv shell --no-tui -- lefthook install

jj-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    jj config set --repo aliases.push \
      '["util", "exec", "--", "bash", "-c", "devenv shell --no-tui -- lefthook run pre-push && jj git push \"$@\"", ""]'
