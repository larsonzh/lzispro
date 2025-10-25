# Git Bash 远程静态交叉编译与测试工具 使用说明

本工具在 Windows 的 Git Bash 中一键发起远程构建：上传代码（排除 .git 与 artifacts）→ 远端静态跨架构编译 → 可选 QEMU 冒烟测试 → 拉回产物 → 远端清理。

- 本地启动器：`release/lzispro/whois/remote/remote_build_and_test.sh`
- 远端构建器：`release/lzispro/whois/remote/remote_build.sh`

PowerShell 启动器已停用，建议全程使用 Git Bash 版本。

## 前置条件

本地（Windows）
- Git Bash 可用（包含 ssh/scp/tar）
- 建议使用 ssh-agent，或准备好私钥（如 `/d/xxx/id_rsa`）

远端（Linux/Ubuntu）
- 已安装交叉编译器（脚本会优先识别这些绝对路径）：
  - aarch64: `~/.local/aarch64-linux-musl-cross/bin/aarch64-linux-musl-gcc`
  - armv7: `~/.local/arm-linux-musleabihf-cross/bin/arm-linux-musleabihf-gcc`
  - x86_64: `~/.local/x86_64-linux-musl-cross/bin/x86_64-linux-musl-gcc`
  - x86(i686): `~/.local/i686-linux-musl-cross/bin/i686-linux-musl-gcc`
  - mipsel: `~/.local/mipsel-linux-musl-cross/bin/mipsel-linux-musl-gcc`
  - mips64el: `~/.local/mips64el-linux-musl-cross/bin/mips64el-linux-musl-gcc`
  - loongarch64: `~/.local/loongson-gnu-toolchain-8.3-.../loongarch64-linux-gnu-gcc`
- 建议安装（可选）：`upx`（压缩 aarch64/x86_64）、`qemu-user-static`（冒烟测试）、`file`（产物信息）。

## 快速开始

默认仅编译（不跑仿真），零参数即可：

```bash
cd /d/LZProjects/lzispro
./release/lzispro/whois/remote/remote_build_and_test.sh
```

指定私钥（单一位置参数即可，等价于 -k；路径含空格要加引号）：

```bash
./release/lzispro/whois/remote/remote_build_and_test.sh "/d/Larson/id_rsa"
```

开启 QEMU 冒烟测试（-r 1）：

```bash
./release/lzispro/whois/remote/remote_build_and_test.sh -r 1
```

仅编译部分目标（更快）：

```bash
./release/lzispro/whois/remote/remote_build_and_test.sh -t "aarch64 x86_64 loongarch64"
```

运行完成，产物将被拉回到：`release/artifacts/<时间戳>/build_out/`，包括：
- 各架构二进制：`whois-<arch>`
- `file_report.txt`（file 命令输出汇总）
- `smoke_test.log`（启用 -r 1 时生成）

## 参数说明

- `-H <host>`：SSH 主机（默认 10.0.0.199）
- `-u <user>`：SSH 用户（默认 larson）
- `-p <port>`：SSH 端口（默认 22）
- `-k <key>`：SSH 私钥路径（可省略并使用 ssh-agent）
- `-R <remote_dir>`：远端工作根目录（默认 `$HOME/lzispro_remote`）
- `-t <targets>`：目标架构（默认 `"aarch64 armv7 x86_64 x86 mipsel mips64el loongarch64"`）
- `-r <0|1>`：是否跑 QEMU 冒烟测试（默认 0）
- `-o <output_dir>`：远端产出目录（默认 `release/build_out`）
- `-f <fetch_to>`：本地拉取基目录（默认 `release/artifacts`）
- `[keyfile]`：单一位置参数，等价于 `-k`（便捷写法）

环境变量也可覆盖同名缺省值（如 `SSH_HOST` / `SSH_USER` 等）。

## 工作原理（简述）

- SSH 免交互：`StrictHostKeyChecking=accept-new`、`UserKnownHostsFile=/dev/null`、`BatchMode=yes`、`LogLevel=ERROR`
- 远端 HOME 探测：以 `$HOME/lzispro_remote/src` 为根（或 `-R` 覆盖）
- 上传：`tar` 流式传输（排除 `.git` 与 `release/artifacts`）
- 远端构建：登录 shell（`bash -l`）执行 `remote_build.sh`，按架构静态编译（`-O3 -s -pthread`）
- UPX：对 aarch64/x86_64 可选压缩（存在时才压）
- QEMU：逐个二进制冒烟（未安装 qemu 不影响整体）
- 回传产物 → 远端清理

## 常见问题

- 私钥路径含空格：请使用引号包裹（Git Bash 路径用正斜杠）。
- 某架构 `not found`：该架构工具链未安装或不在固定路径；可先用 `-t` 构建已安装的目标。
- `smoke_test.log` 为空：可能未加 `-r 1`，或远端缺少 `qemu-*-static`。
- 反复出现已添加 Known Hosts：脚本已将日志等级降为 ERROR，并使用内存 known_hosts，正常现象。

## 安全与清理

- 远端工作目录完成后自动 `rm -rf` 清理。
- 如需要严格主机指纹校验，可去掉 `UserKnownHostsFile=/dev/null`，首次连接时手动接受指纹。

---

如需把默认目标缩减到常用的 `aarch64 x86_64` 以加速，或把说明同步到顶层 README，请提 issue/告知维护者即可。
