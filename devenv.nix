{ pkgs, ... }:
# 只釘一樣東西：編譯器。
#
# 競賽 judge 是 gcc/g++ 13.3.0 + C++17（臺北市 115 學年度資訊學科能力競賽
# 實施計畫，附件一第 10 點）。WSL Ubuntu 24.04 的 rootfs **完全不帶 gcc/g++**，
# 所以必須裝；而一旦裝了，就必須釘住 —— Ubuntu LTS 的 -updates 會推 gcc 13.x
# 的 patch 版，`apt install g++` 今天給 13.3.0、半年後可能給 13.4.0，那個漂移
# 會讓學生練出 judge 不接受的东西。nixpkgs 25.05 的 gcc13 正好是 13.3.0。
#
# 其餘工具一律**不**放進這裡，改用 distro 現成的：
#   vim 9.1.0016  ← rootfs 自帶，正是簡章寫的 9.1
#   python3 / git / diffutils / time ← rootfs 自帶
# 理由：judge 不用 vim 或 python 編譯，它們的版本不影響提交；多裝一個就多一次
# 下載；而 distro 已帶的版本已經對得上規格。少即是對。
#
# 唯一的例外是 just。Ubuntu 24.04 的 WSL rootfs 不帶它（已對照 Canonical 的
# package manifest 逐項確認），而它是「學生、CI、pre-push 跑同一份 recipe」的
# 唯一機制，沒有它就退化回三份各自漂移的程式碼。一個 Go binary，代價很小。
# 第一次精簡時我把它也刪了，結果 CI 直接 exec: just: not found —— 本地會過
# 是因為我自己的 nix profile 裡有 just，這就是為甚麼這類事必須在乾淨環境測。
let
  gcc13 = pkgs.gcc13;
in
{
  packages = with pkgs; [
    just
    gcc13
  ];

  dotenv.enable = false;

  # 絕對路徑，不靠 PATH 解析 `g++`。學生 PATH 裡只要出現別的 g++（自己 apt
  # 裝的、nix profile 加的），走名字就會靜默用錯版本。
  env.GCC_BIN = "${gcc13}/bin/g++";

  enterShell = ''
    echo "ioi-env — g++ $(g++ --version | head -1 | grep -o '[0-9.]*$') · C++17 (judge 用這版)"
    echo "  vim $(vim --version | head -1 | awk '{print $5}') · python3 $(python3 --version 2>&1 | awk '{print $2}')  ← distro 現成"
    echo ""
    echo "  vim work/sol.cpp       寫題"
    echo "  F5                     編譯執行 (g++ -O2 -std=c++17 -Wall)"
    echo "  just check-env         釘子漂了會紅"
  '';
}
