{ pkgs, ... }:
# 釘死 gcc13：競賽 judge 是 gcc/g++ 13.3.0 + C++17
# （臺北市 115 學年度資訊學科能力競賽實施計畫，附件一第 10 點）。
# 只釘編譯器與語言標準，不追求 OS point release —— 賽場的 Ubuntu 24.04.2
# 無法由 `wsl --install -d Ubuntu-24.04` 取得，也不影響編譯行為，理由見
# README「About the OS version」。
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
    echo "  g++:  $(g++ --version | head -1 | grep -o '[0-9.]*$')  C++17  <- judge uses this one"
    echo "  vim:  $(vim --version | head -1 | awk '{print $5}')"
    echo "  os:   $(. /etc/os-release && echo "$PRETTY_NAME")"
    echo ""
    echo "  vim work/sol.cpp     write your solution"
    echo "  F5                   compile + run (g++ -O2 -std=c++17 -Wall)"
    echo "  just check-env       fail loudly if the pins drifted"
    echo ""
  '';
}
