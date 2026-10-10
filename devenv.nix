{ pkgs, ... }:
# 釘死 gcc13：競賽環境是 Ubuntu 24.04 + gcc/g++ 13.3.0 + C++17
# （臺北市 115 學年度資訊學科能力競賽實施計畫，附件一第 10 點）。
#
# nixpkgs 的無版本 `gcc` 目前是 15.3.0。拿它練會養出「C++23 語法本地過、
# judge 編不過」的習慣，所以這裡只認 gcc13。
# 13.4.0 vs 簡章 13.3.0 只差 patch 級，C++17 行為一致，不影響備賽。
let
  gcc13 = pkgs.gcc13;
in
{
  packages = with pkgs; [
    just
    git
    gcc13
    gdb
    vim
    python3
    time
    gnumake
    diffutils
  ];

  dotenv.enable = false;

  # 給 vimrc / 腳本 / MCP 用的絕對路徑，不靠 PATH 解析。
  # 只要別人 PATH 裡有別的 g++（學生自己 apt 裝的、nix profile 加的），
  # 走名字 `g++` 就會靜默用錯版本。
  env.GCC_BIN = "${gcc13}/bin/g++";

  # C 語言支援；C++ 由 gcc13 提供，不需要額外 language 模組。
  languages.c.enable = true;

  enterShell = ''
    echo "ioi-env (student shell)"
    echo "  g++:    $(g++ --version | head -1 | grep -o '[0-9.]*$')  C++17  ← 對齊競賽環境"
    echo "  vim:    $(vim --version | head -1 | awk '{print $5}')"
    echo ""
    echo "  vim work/sol.cpp     寫題"
    echo "  F5                   編譯執行 (g++ -O2 -std=c++17 -Wall)"
    echo "  just check-env       檢查環境有沒有漂"
    echo ""
  '';
}
