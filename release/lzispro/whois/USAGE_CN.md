# whois 客户端使用说明（中文）

本说明适用于项目内置的轻量级 whois 客户端（C 语言实现，静态编译，零外部依赖）。二进制覆盖多架构，例如 `whois-x86_64`、`whois-aarch64` 等，以下示例以 `whois-x86_64` 为例。

## 一、核心特性（3.1.0）
- 批量标准输入：`-B/--batch` 或“无位置参数 + stdin 非 TTY”隐式进入
- 标题头与权威 RIR 尾行（默认开启；`-P/--plain` 纯净模式关闭）
  - 头：`=== Query: <查询项> ===`，查询项在标题行第 3 字段（`$3`）
  - 尾：`=== Authoritative RIR: <server> ===`，折叠后位于最后一个字段（`$(NF)`）
- 非阻塞 connect + IO 超时 + 轻量重试（默认 2 次）；自动重定向（`-R` 上限，`-Q` 可禁用），循环防护

## 二、命令行用法

```
Usage: whois-<arch> [OPTIONS] <IP or domain>

Options:
  -h, --host HOST          指定起始 whois 服务器（别名或域名，例如 apnic / whois.apnic.net）
  -p, --port PORT          指定端口（默认 43）
  -b, --buffer-size SIZE   响应缓冲区大小，支持 1K/1M 等单位（默认 512K）
  -r, --retries COUNT      单次请求内最大重试次数（默认 2）
  -t, --timeout SECONDS    网络超时（默认 5s）
  -i, --retry-interval-ms MS  重试间隔基准毫秒数（默认 300）
  -J, --retry-jitter-ms MS    额外抖动（0..MS 毫秒，默认 300）
  -R, --max-redirects N    自动重定向最大次数（默认 5）
  -Q, --no-redirect        禁止跟随重定向（只查起始服务器）
  -B, --batch              从标准输入读取查询项（每行一条），启用后禁止提供位置参数
  -P, --plain              纯净输出（不打印标题与 RIR 尾行）
  -D, --debug              打印调试信息（stderr）
  -l, --list               列出内置的 whois 服务器别名
  -v, --version            打印版本信息
  -H, --help               打印帮助
```

说明：
- 若未提供位置参数且 stdin 非 TTY，会隐式进入批量模式；`-B` 为显式批量开关。
- `-Q` 禁止重定向时，尾行的 RIR 仅表示“实际查询的服务器”，不保证为权威 RIR。

## 三、输出契约（用于 BusyBox 管道）

- 标题头：`=== Query: <查询项> ===`，查询项位于 `$3`
- 尾行：`=== Authoritative RIR: <server> ===`，折叠为一行后位于 `$(NF)`
- 私网 IP：正文为 `"<ip> is a private IP address"`，尾行 RIR 为 `unknown`

折叠示例（与脚本 `func/lzispdata.sh` 风格一致）：

```sh
... | grep -Ei '^(=== Query:|netname|mnt-|e-mail|=== Authoritative RIR:)' \
  | awk -v count=0 '/^=== Query/ {if (count==0) printf "%s", $3; else printf "\n%s", $3; count++; next} \
      /^=== Authoritative RIR:/ {printf " %s", toupper($4)} \
      (!/^=== Query:/ && !/^=== Authoritative RIR:/) {printf " %s", toupper($2)} END {printf "\n"}'
# 注：折叠后 `$(NF)` 即为权威 RIR 域名（大写），可用于 RIR 过滤
```

## 四、常用示例

```sh
# 单条（自动重定向）
whois-x86_64 8.8.8.8

# 指定起始 RIR 并禁止重定向
whois-x86_64 --host apnic -Q 103.89.208.0

# 批量（显式）：
cat ip_list.txt | whois-x86_64 -B --host apnic

# 纯净输出（无标题/尾行）
whois-x86_64 -P 8.8.8.8
```

## 五、退出码
- 0：成功（含批量模式下的局部失败，失败会逐条打印到 stderr）
- 非 0：参数错误 / 无输入 / 单条模式查询失败

## 六、提示
- 建议与 BusyBox 工具链配合：grep/awk/sed 排序、去重、聚合留给外层脚本处理
- 如需固定出口且避免跳转带来的不稳定，可使用 `--host <rir> -Q`
- 在自动重定向模式下，`-R` 过小可能拿不到权威信息；过大可能产生延迟，默认 5 足够
- 重试节奏：默认 `interval=300ms` 且 `jitter=300ms`，即每次重试等待区间约为 `[300, 600]ms`，能有效打散拥塞与抖动；可按需通过 `-i/-J` 调整。

## 七、版本
- 3.1.0（Batch mode, headers+RIR tail, non-blocking connect, timeouts, redirects；默认重试节奏：interval=300ms, jitter=300ms）

