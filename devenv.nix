{ pkgs, ... }:
# 臺北市 115 學年度資訊學科能力競賽（地區複賽）本地練習環境。
#
# 簡章附件一第 10 點：
#   OS Ubuntu 24.04.2 · Compiler gcc/g++ 13.3.0 · C++17 · vim 9.1
#
# 為什麼只有 gcc 走 nix：WSL Ubuntu 24.04 的 rootfs 不帶 gcc/g++，所以必須裝；
# 裝了就必須釘住，否則 Ubuntu LTS 的 -updates 會把 gcc 13.x 推上走，學生會練出
# judge 不接受的东西。nixpkgs 25.05 的 gcc13 正好是 13.3.0。
#
# 其餘用 distro 現成的（已對照 Canonical 的 package manifest 逐項確認）：
#   vim 9.1.0016 ← rootfs 自帶，正是簡章寫的 9.1
#   git / python3 / diffutils / time ← rootfs 自帶
# just 是唯一例外：rootfs 不帶它，而它是「學生、CI、pre-push 跑同一份 recipe」的
# 機制。少了它本地會靜靜用我 nix profile 裡的 just 而 CI 才炸——已為此加了
# purity 檢查到 check-env，讓這類錯誤在本地就見到。
let
  gcc13 = pkgs.gcc13;
in
{
  packages = with pkgs; [
    just
    gcc13
    gdb
    gnumake
    diffutils
    python3
    time
    zsh
    oh-my-zsh
  ];

  dotenv.enable = false;

  env.GCC_BIN = "${gcc13}/bin/g++";

  enterShell = ''
    echo ""
    echo "  ioi-env — 臺北市資訊學科能力競賽 地區複賽"
    echo "  ────────────────────────────────────────"
    echo "  g++  $(g++ --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')   C++17   (規格 13.3.0)"
    echo "  vim  $(vim --version | head -1 | awk '{print $5}')                       (規格 9.1)"
    echo "  gdb  $(gdb --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
    echo ""
    echo "  vim a.cpp      寫題"
    echo "  F5             編譯執行"
    echo "  F7             ASan/UBSan 執行"
    echo "  <Leader>d      gdb"
    echo ""
  '';
}
