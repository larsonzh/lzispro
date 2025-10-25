# whois client usage (English)

This document describes the built-in lightweight whois clients shipped with the project (C implementation, statically linked, zero external runtime deps). Binaries cover multiple architectures such as `whois-x86_64`, `whois-aarch64`, etc. Examples below use `whois-x86_64`.

## 1. Key features (3.1.0)
- Batch stdin: `-B/--batch` (or implicit when no positional arg and stdin is not a TTY)
- Header + authoritative RIR tail (enabled by default; disable with `-P/--plain`)
  - Header: `=== Query: <query> ===`, the query token sits at field `$3`
  - Tail: `=== Authoritative RIR: <server> ===`, after folding into one line it becomes the last field `$(NF)`
- Non-blocking connect + IO timeouts + light retry (default 2); automatic redirects (cap by `-R`, disable with `-Q`), loop guard

## 2. Command line

```
Usage: whois-<arch> [OPTIONS] <IP or domain>

Options:
  -h, --host HOST          Specify starting whois server (alias or domain, e.g. apnic / whois.apnic.net)
  -p, --port PORT          Port number (default 43)
  -b, --buffer-size SIZE   Response buffer size, supports 1K/1M/1G suffixes (default 512K)
  -r, --retries COUNT      Max retry times per single request (default 2)
  -t, --timeout SECONDS    Network timeout (default 5s)
  -i, --retry-interval-ms MS  Base sleep between retries in milliseconds (default 300)
  -J, --retry-jitter-ms MS    Extra random jitter in milliseconds (0..MS, default 300)
  -R, --max-redirects N    Max referral redirects to follow (default 5)
  -Q, --no-redirect        Do NOT follow redirects (only query the starting server)
  -B, --batch              Read queries from stdin (one per line); forbids positional query
  -P, --plain              Plain output (suppress header and RIR tail lines)
  -D, --debug              Debug logs to stderr
  -l, --list               List built-in whois server aliases
  -v, --version            Show version
  -H, --help               Show help
```

Notes:
- If no positional query is provided and stdin is not a TTY, batch mode is enabled implicitly; `-B` enables it explicitly.
- With `-Q` (no redirect), the tail RIR just shows the actual queried server and may NOT be authoritative.

## 3. Output contract (for BusyBox pipelines)
- Header: `=== Query: <query> ===`, query is `$3`
- Tail: `=== Authoritative RIR: <server> ===`, after folding becomes `$(NF)`
- Private IP: body prints `"<ip> is a private IP address"` and RIR tail is `unknown`

Folding example (aligned with `func/lzispdata.sh` style):

```sh
... | grep -Ei '^(=== Query:|netname|mnt-|e-mail|=== Authoritative RIR:)' \
  | awk -v count=0 '/^=== Query/ {if (count==0) printf "%s", $3; else printf "\n%s", $3; count++; next} \
      /^=== Authoritative RIR:/ {printf " %s", toupper($4)} \
      (!/^=== Query:/ && !/^=== Authoritative RIR:/) {printf " %s", toupper($2)} END {printf "\n"}'
# Tip: after folding, `$(NF)` is the authoritative RIR (uppercase), suitable for filtering
```

## 4. Common examples

```sh
# Single (with auto redirects)
whois-x86_64 8.8.8.8

# Force starting RIR and disable redirects
whois-x86_64 --host apnic -Q 103.89.208.0

# Batch (explicit)
cat ip_list.txt | whois-x86_64 -B --host apnic

# Plain output (no header/tail)
whois-x86_64 -P 8.8.8.8
```

## 5. Exit codes
- 0: success (in batch mode, individual failures are printed to stderr)
- non-zero: invalid args / no input / single query failed

## 6. Tips
- Prefer leaving sorting/dedup/aggregation to outer BusyBox scripts (grep/awk/sed)
- To stick to a fixed server and minimize instability from redirects, use `--host <rir> -Q`
- In automatic redirects mode, too small `-R` may lose authoritative info; too large may add latency; default 5 is typically enough
- Retry pacing: default `interval=300ms` and `jitter=300ms`, so each retry sleeps within `[300, 600]ms`, which helps mitigate bursty failures; tune via `-i/-J` if needed.

## 7. Version
- 3.1.0 (Batch mode, headers+RIR tail, non-blocking connect, timeouts, redirects; default retry pacing: interval=300ms, jitter=300ms)
