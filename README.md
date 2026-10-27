# opencode-kit

Bộ kit sao lưu & khôi phục toàn bộ setup **OpenCode + Finder** (macOS arm64) sang máy mới bằng 1 lệnh.

## Khôi phục trên máy mới (1 lệnh)

```bash
git clone https://github.com/ptthien97/opencode-kit.git ~/opencode-kit && ~/opencode-kit/install.sh
```

Tuỳ chọn:

- `--dry-run` — chỉ in ra sẽ làm gì
- `--no-finder` — bỏ qua tải binary finder
- `--with-services` — cài + bootstrap LaunchAgent tavily-key-pool
- `--profile NAME` — áp profile model (default/cheap/strong), không hỏi
- `--pick-models` — mở picker chọn model theo từng role
- `--no-prompt` — không hỏi gì; giữ default hoặc dùng env `KIT_MODEL_*` / `KIT_USER_*`

Target cũ (nếu có) được backup thành `<target>.bak-<timestamp>` (chmod 700) trước khi ghi đè. Script idempotent, chạy lại an toàn.

## Bên trong có gì

| Phần | Nội dung |
| --- | --- |
| `home/.config/opencode/` | `opencode.json` (secret đã gắn lại `{file:...}`), `AGENTS.md` (đã ẩn danh), `agents/`, `plugins/`, `skills/`, `tools/tavily-key-pool` (không có `config.yaml`) |
| `home/.claude/skills/` | finder-kit, worker-kit, reverse-engineer-anything, `synced/claude-account` (snapshot của `synced/<uuid>` — tên UUID là account id nên được đổi tên trung lập; không thứ gì tham chiếu UUID đó) |
| `home/.agents/skills/` | 43 skill dùng chung |
| `templates/` | `finder-settings.json` (secret thay `<REDACTED>`), `local.tavily-key-pool.plist` |
| `roles.conf` | Định nghĩa role -> target config + mô tả (dùng chung bởi set-model.sh, install.sh) |
| `profiles/` | `default.env` (mapping máy gốc), `cheap.env`, `strong.env` |
| `sync.sh` / `install.sh` / `set-model.sh` | 3 script chính |

Đường dẫn tuyệt đối trong snapshot đã thay `$HOME` → `__HOME__`; path/tên dự án thật → `__EXAMPLE_REPO__`/`project-*`; tên người dùng → `__USER_*__`. `install.sh` thay ngược lại khi cài. Cặp thay thế thật nằm ở `.kit-local.env` (gitignored, tự tạo lần sync đầu từ dữ liệu live — sửa tay được). Binary `finder` (~84MB) **không** nằm trong git — là asset trên GitHub Releases (tag + sha256 trong `kit.conf`).

## Chọn model cho từng role

Role định nghĩa trong `roles.conf`:

| Role | Target | Gợi ý tier |
| --- | --- | --- |
| `main` | `model` top-level opencode.json | mạnh nhất |
| `small` | `small_model` + title/summary/compaction | rẻ, nhanh |
| `orchestrator` | agents/orchestrator.md | mạnh |
| `worker` | agents/worker.md (bị env `WORKER_MODEL` ghi đè lúc worker-kit dispatch) | vừa/rẻ |
| `junior-dev` | agents/junior-dev.md | rẻ |
| `senior-dev` | agents/senior-dev.md | vừa |
| `10x-dev` | agents/10x-dev.md | mạnh |
| `reviewer` | agents/reviewer.md | mạnh |
| `teach` | agents/teach.md | mạnh |
| `explore` | agents.explore trong opencode.json | rẻ |
| `general` | agents.general trong opencode.json | vừa/rẻ |

Ví dụ:

```bash
./set-model.sh list                              # xem role -> model hiện tại
./set-model.sh pick                              # picker từng role (Enter = giữ); ghi kit-profile.env
./set-model.sh worker vua/kimi-k3                # đổi 1 role
./set-model.sh --profile cheap                   # áp profile có sẵn
KIT_MODEL_WORKER=vua/kimi-k3 ./install.sh --no-finder --no-prompt   # script hoá qua env
```

Mọi thay đổi đều backup file trước (`*.bak-<timestamp>`). Giá trị có thể kèm variant: `provider/model#max`.
Lần cài lại: `install.sh` tự đọc `~/.config/opencode/kit-user.env` và `kit-profile.env` đã lưu.

## Secrets — repo public KHÔNG chứa, phải tự điền sau khi cài

1. `~/.secrets/opencode/vua-apikey` — API key provider `vua` (llmrouter.space)
2. `~/.secrets/opencode/localproxyapi-apikey` — key local proxy `http://127.0.0.1:8317`
3. `~/.secrets/opencode/context7-apikey` — key Context7 MCP
4. `~/.secrets/opencode/finder-token` — Bearer token Finder MCP
5. `~/.finder/settings.json` — điền các trường `<REDACTED>`: `embedding.api_keys`, `jev.api_keys`, `gateway.api_key`, `gateway.key_prefix`
6. `~/.config/opencode/tools/tavily-key-pool/config.yaml` — `cp config.example.yaml config.yaml` rồi chỉnh

`install.sh` in checklist này ở bước cuối và không bao giờ ghi đè file secret đã có.

## Đồng bộ sau khi đổi config (trên máy chính)

```bash
~/opencode-kit/sync.sh           # rsync -> snapshot, ẩn danh, che secret, quét secret
~/opencode-kit/sync.sh --push    # + git commit "sync: <ngày>" và push
```

Secret scan fail (exit 1) nếu phát hiện key thật trong repo (12 pattern + exact-match với mọi secret live); đường dẫn allowlist nằm ở đầu `sync.sh` (hiện chỉ có 1 fixture test giả trong skill `management-report-docx`).

## Release binary finder mới

```bash
gh release create finder-v1.2.5 ~/.local/bin/finder#finder-darwin-arm64 -R "$(grep ^KIT_REPO= kit.conf | cut -d'"' -f2)"
# rồi bump FINDER_RELEASE_TAG / FINDER_VERSION / FINDER_SHA256 trong kit.conf
# (sha256 lấy bằng: shasum -a 256 ~/.local/bin/finder), chạy sync.sh --push
```
