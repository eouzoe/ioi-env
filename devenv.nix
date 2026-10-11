{ pkgs, ... }:
# 臺北市 115 學年度資訊學科能力競賽（地區複賽）本地練習環境。
#
# 簡章附件一第 10 點：
#   OS Ubuntu 24.04.2 · Compiler gcc/g++ 13.3.0 · C++17 · vim 9.1
#
# WSL Ubuntu 24.04 的 rootfs 不帶 gcc/g++，所以編譯器必須裝；裝了就必須釘住，
# 否則 Ubuntu LTS 的 -updates 會把 gcc 13.x 推上走，學生會練出 judge 不接受的东西。
# nixpkgs 25.05 的 gcc13 正好是 13.3.0。
#
# 除錯與工具鏈：gdb + ASan/UBSan（g++ 內建）+ make/diff/python3/time。
# shell：zsh + oh-my-zsh。
let
  gcc13 = pkgs.gcc13;
  omz = pkgs.oh-my-zsh;
in
{
  packages = with pkgs; [
    # 競賽規格
    gcc13
    vim
    # 除錯
    gdb
    # 工具鏈
    gnumake
    diffutils
    python3
    time
    # shell
    zsh
    oh-my-zsh
  ];

  dotenv.enable = false;

  env.GCC_BIN = "${gcc13}/bin/g++";

  # oh-my-zsh 在 nix store 裡，用 ZSH 指過去；complist/compinit 需要這個目錄可寫，
  # 所以複製到 .devenv 底下而不是直接用 store path。
  env.ZSH = "${omz}/share/oh-my-zsh";
  env.ZSH_CUSTOM = ".devenv/oh-my-zsh-custom";

  languages.c.enable = true;

  # 讓 `devenv shell` 進到 zsh，並帶上 oh-my-zsh。
  files.oh-my-zsh-init.text = ''
    export ZSH="${omz}/share/oh-my-zsh"
    export ZSH_THEME="robbyrussell"
    plugins=(git)
    ZSH_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"
    mkdir -p "$ZSH_CACHE_DIR"
    source "$ZSH/oh-my-zsh.sh"
  '';

  enterShell = ''
    echo ""
    echo "  ioi-env — 臺北市資訊學科能力競賽 地區複賽練習環境"
    echo "  ────────────────────────────────────────────────"
    echo "  g++  $(g++ --version | head -1 | grep -o '[0-9.]*$')   C++17   (競賽規格 13.3.0)"
    echo "  vim  $(vim --version | head -1 | awk '{print $5}')          (競賽規格 9.1)"
    echo "  gdb  $(gdb --version | head -1 | awk '{print $5}')"
    echo ""
    echo "  vim a.cpp          寫題"
    echo "  F5                 編譯執行"
    echo "  <Leader>g          gdb ./a"
    echo ""
  '';
}
