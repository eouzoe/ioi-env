{ pkgs, ... }:
# 釘死 gcc13：競賽環境是 Ubuntu 24.04.2 + gcc/g++ 13.3.0 + C++17
# （臺北市 115 學年度資訊學科能力競賽實施計畫，附件一第 10 點）。
#
# devenv.yaml 把 nixpkgs 釘在 25.05，那一版 gcc13 正好是 13.3.0、vim 是 9.1，
# 與簡章逐字對齊。不要換回無版本 `gcc`（rolling 下是 15.3.0）：拿它練會養出
# 「C++23 語法本地過、judge 編不過」的習慣，這是唯一會在賽場致命的漂移。
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

  # 絕對路徑，不靠 PATH 解析 `g++`。學生 PATH 裡只要出現別的 g++（自己 apt
  # 裝的、nix profile 加的），走名字就會靜默用錯版本。
  env.GCC_BIN = "${gcc13}/bin/g++";

  languages.c.enable = true;

  enterShell = ''
    echo "ioi-env (student shell)"
    echo "  g++:    $(g++ --version | head -1 | grep -o '[0-9.]*$')  C++17  ← 競賽環境"
    echo "  vim:    $(vim --version | head -1 | awk '{print $5}')"
    echo "  os spec: Ubuntu 24.04.2 + gcc/g++ 13.3.0 + vim 9.1"
    echo ""
    echo "  vim work/sol.cpp     寫題"
    echo "  F5                   編譯執行 (g++ -O2 -std=c++17 -Wall)"
    echo "  just check-env       檢查環境有沒有漂"
    echo ""
  '';
}
