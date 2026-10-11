# ioi-env

臺北市 115 學年度資訊學科能力競賽（地區複賽）本地練習環境。一行裝好。

## 安裝

```bash
curl -fsSL https://raw.githubusercontent.com/eouzoe/ioi-env/main/scripts/start.sh | bash
```

## 裝什麼

依簡章附件一第 10 點：

| | 規格 |
|---|---|
| OS | Ubuntu 24.04 |
| Compiler | gcc/g++ **13.3.0** |
| Language | C++17 |
| Editor | vim **9.1** |

| 工具 | 版本 | 用途 |
|---|---|---|
| `gcc13` | 13.3.0 | 編譯器，nix 釘死 |
| `vim` | 9.1 | 編輯器 |
| `gdb` | 16.2 | 除錯 |
| `make` / `diff` / `python3` / `time` | — | 對拍與計時 |
| `zsh` + `oh-my-zsh` | 5.9 / 2025-04-29 | shell |

WSL Ubuntu 24.04 的 rootfs 不帶 gcc/g++，所以編譯器必須裝；裝了就必須釘住，
否則 Ubuntu LTS 的 `-updates` 會把 gcc 13.x 推上走，學生會練出 judge 不接受的东西。
nixpkgs 25.05 的 gcc13 正好是 13.3.0。

## 用

```bash
cd ~/ioi-env && devenv shell     # 進入（zsh + oh-my-zsh）
vim a.cpp                        # 寫題
```

vim 按鍵（都已實測可用）：

| 鍵 | 動作 |
|---|---|
| `F5` | 編譯 + 執行（stdin） |
| `F6` | 只編譯檢查語法 |
| `F7` | ASan/UBSan 編譯 + 執行 |
| `F8` | `/usr/bin/time -v` 量時間與記憶體 |
| `<Leader>d` | gdb 除錯 |
| `<Leader>i` | 開 `input.txt` |
| `<Leader>w` | 存檔 |
| `jj` | 離開 insert |

`F7` 跑在 `setarch -R` 底下是必要的：nix 的 ASan runtime 在高 ASLR 位址下偶發
mmap 失敗（實測 30 次有 6 次靜默 SEGV）。

## 只寫兩個檔案

`~/.vimrc` 和 `~/.zshrc`，而且**只在你沒有的時候寫**，已有的絕對不動。

**不碰你機器上任何其他東西**：沒有 `.wslconfig`（那是你的，你的機器需要你的數字）、
沒有 `/etc/wsl.conf`、沒有時區、沒有 apt、沒有背景服務。編譯器在 nix store 裡，
不在你的檔案系統；卸載就是把 `~/ioi-env` 刪掉。

## OS 版本

簡章寫 Ubuntu 24.04.2。`wsl --install -d Ubuntu-24.04` 裝到的是 Canonical 最新发布
的版本（今天為 24.04.5）——Store appx 沒有版本選項，
`cloud-images.ubuntu.com/wsl/releases/noble/` 也只有 `20240423/`（=24.04.0）和
`current/` 兩個。不影響：judge 用它自己的 gcc 13.3.0 編譯，我們的是 nix 釘的。

## Maintainer

```bash
cp devenv.local.nix.example devenv.local.nix   # lefthook, shellcheck, actionlint
just hooks
just jj-setup
```

`jj git push` 不跑 git hooks，所以 `jj-setup` 加一個 jj alias 先跑檢查再推。

## CI

| Job | 驗什麼 |
|---|---|
| `lint` | shellcheck + actionlint |
| `wsl` | 空白 Windows → 裝 WSL Ubuntu 24.04 → 在 WSL 內跑學生那一行 |

`wsl` job 也測真實機器才会遇到、乾淨 runner 不會的路徑：既有 `~/.vimrc` 不能動、
`start.sh` 自己抓 repo、整條路可重跑、主機沒被改動。
