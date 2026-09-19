# opencode

opencode **V2** config, plus the runbook for setting it up on a new machine or
migrating a machine still running V1.

## Layout

| File                  | Symlinked to                       | Purpose                                            |
| --------------------- | ---------------------------------- | -------------------------------------------------- |
| `opencode.jsonc`      | `~/.config/opencode/opencode.jsonc` | Server/project config: providers, MCP, permissions, agents |
| `cli.json`            | `~/.config/opencode/cli.json`       | Terminal client config: theme, notifications, keybinds |

Not tracked here (machine-local, contains a secret):

| File                          | Purpose                                     |
| ----------------------------- | ------------------------------------------- |
| `~/.cli-proxy-api/config.yaml` | CLIProxyAPI gateway config + local API key  |
| `~/.cli-proxy-api/claude-*.json` | Claude OAuth tokens                      |

## Architecture

```
opencode V2 (background service)
  ├─ anthropic ──► CLIProxyAPI @ 127.0.0.1:8317 ──► Claude Code OAuth subscription
  └─ openai    ──► native ChatGPT OAuth (/connect)
```

Anthropic is routed through [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI),
a local gateway that turns a Claude Code subscription into an Anthropic-compatible
API. This replaces the V1-only `opencode-claude-auth` plugin, which does not run
under V2.

CLIProxyAPI exposes the stock Anthropic wire protocol at `/v1/messages` **and the
stock model IDs** (`claude-opus-4-8`, `claude-opus-5`, …), so the built-in
`anthropic` provider is reused as-is — only `baseURL` and `apiKey` are overridden.
No custom provider or model-ID remapping needed.

OpenAI deliberately does *not* go through the proxy; V2 has native ChatGPT OAuth.

---

## Fresh setup on a new machine

### 1. CLIProxyAPI

```bash
brew install cliproxyapi                      # macOS
# Linux: curl -fsSL https://raw.githubusercontent.com/router-for-me/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer | bash
# Arch:  paru -S cli-proxy-api-bin
```

Generate a machine-local key and write the config:

```bash
mkdir -p ~/.cli-proxy-api
KEY="cpa-$(openssl rand -hex 24)"
cat > ~/.cli-proxy-api/config.yaml <<EOF
host: "127.0.0.1"
port: 8317
auth-dir: "~/.cli-proxy-api"
api-keys:
  - "$KEY"
debug: false
logging-to-file: false
usage-statistics-enabled: false
request-retry: 3
remote-management:
  allow-remote: false
  secret-key: ""
EOF
chmod 600 ~/.cli-proxy-api/config.yaml
echo "$KEY" > ~/.cli-proxy-api/.opencode-key
chmod 600 ~/.cli-proxy-api/.opencode-key
```

The key is a local-only shared secret between opencode and the gateway, not a
provider credential. Generate a **different one per machine**; never commit it.

On macOS, `brew services` reads `$(brew --prefix)/etc/cliproxyapi.conf`. Point it
at the home config (the target must exist first, or the service exits immediately):

```bash
brew_conf="$(brew --prefix)/etc/cliproxyapi.conf"
brew services stop cliproxyapi
[ -f "$brew_conf" ] && [ ! -L "$brew_conf" ] && mv "$brew_conf" "$brew_conf.bak.$(date +%Y%m%d-%H%M%S)"
ln -sfn "$HOME/.cli-proxy-api/config.yaml" "$brew_conf"
```

Bind the Claude subscription via OAuth, then start the service:

```bash
cliproxyapi --config ~/.cli-proxy-api/config.yaml --claude-login
brew services start cliproxyapi
```

`--claude-login` opens a browser (add `--no-browser` to print the URL instead) and
listens for the callback on port **54545**. It prints an SSH-tunnel suggestion —
ignore it, that is only for remote servers.

Verify:

```bash
KEY=$(cat ~/.cli-proxy-api/.opencode-key)
curl -s http://127.0.0.1:8317/v1/models -H "Authorization: Bearer $KEY" | jq -r '.data[].id'
curl -s http://127.0.0.1:8317/v1/messages \
  -H "content-type: application/json" -H "x-api-key: $KEY" -H "anthropic-version: 2023-06-01" \
  -d '{"model":"claude-opus-4-8","max_tokens":32,"messages":[{"role":"user","content":"Reply with exactly: PROXY_OK"}]}'
```

### 2. opencode V2

```bash
curl -fsSL https://opencode.ai/v2/install | bash
# or: brew install anomalyco/tap/opencode-v2  |  npm i -g @opencode/cli
opencode --version   # expect 2.x
```

### 3. Link the configs

```bash
mkdir -p ~/.config/opencode
ln -sfn "$HOME/projects/dotfiles/opencode/opencode.jsonc" ~/.config/opencode/opencode.jsonc
ln -sfn "$HOME/projects/dotfiles/opencode/cli.json"       ~/.config/opencode/cli.json
```

### 4. Give the server the gateway key

`opencode.jsonc` references `{env:CLIPROXY_API_KEY}`. V2 runs a **shared background
server**, so a shell `export` will not reach it. Register the variable with the
service instead:

```bash
opencode service set env CLIPROXY_API_KEY "$(cat ~/.cli-proxy-api/.opencode-key)"
opencode service get env       # verify
```

This stops a running service; the next `opencode` command restarts it with the
new value.

### 5. Connect OpenAI

```bash
opencode auth login openai     # or /connect in the TUI
```

### 6. Verify

```bash
opencode auth list             # OpenAI OAuth stored; Anthropic should be ABSENT (see gotcha below)
opencode mcp list              # context7 / exa / gh_grep connected, playwright disabled
opencode run --model anthropic/claude-opus-4-8 "Reply with exactly: V2_ANTHROPIC_OK"
```

---

## Migrating a machine from V1

1. **Back up first.** The V2 curl installer writes to the *same* path as V1
   (`~/.opencode/bin/opencode`) and overwrites it.

   ```bash
   mkdir -p ~/.opencode/v1-backup
   cp ~/.opencode/bin/opencode           ~/.opencode/v1-backup/opencode-v1
   cp ~/.local/share/opencode/auth.json  ~/.opencode/v1-backup/
   cp ~/.config/opencode/tui.json        ~/.opencode/v1-backup/ 2>/dev/null
   ```

   Rollback is `cp ~/.opencode/v1-backup/opencode-v1 ~/.opencode/bin/opencode`, or
   re-run the V1 installer at `https://opencode.ai/install`.

2. Run the fresh-setup steps above. V2 imports the legacy `auth.json` into its
   SQLite DB (`~/.local/share/opencode/opencode.db`) on first start, so OpenAI
   carries over automatically.

3. Remove the V1 plugin leftovers once V2 is verified:

   ```bash
   rm -rf ~/.config/opencode/{package.json,package-lock.json,node_modules,bun.lock}
   rm -f  ~/.config/opencode/opencode-notifier-state.json
   ```

   `tui.json` can stay — V2 ignores it, and it is the V1 fallback.

### Gotchas hit during this migration

- **A saved Anthropic account shadows the config `apiKey`.** V1's
  `opencode-claude-auth` left an Anthropic OAuth credential in `auth.json`, which
  V2 imports and then *prefers* over `providers.anthropic.settings.apiKey`. The
  result is a confusing `HTTP 401` from the gateway. Fix:

  ```bash
  opencode auth list --format json          # grab the anthropic credential ID
  opencode auth logout anthropic <cred_id>  # non-interactive needs the ID
  ```

  After that, the config credential is the only one and requests flow through the
  proxy. Re-check this after any future `auth.json` import.

- **`opencode.ai/config.json` still serves the V1 schema.** Editors will flag
  `update` / `providers` / `permissions` / `agents` / `mcp.servers` as unknown
  keys. The V2 runtime accepts them. `cli.json`'s schema
  (`opencode.ai/v2/cli.json`) *is* published and correct.

- **Already-running V1 sessions keep running V1.** The installer replaces the file
  at `~/.opencode/bin/opencode`, but live processes hold the old inode. A V1 TUI
  open during the upgrade keeps its V1 binary, its V1 config interpretation, and
  its V1 plugins (the notifier will keep rewriting
  `~/.config/opencode/opencode-notifier-state.json`). Quit and relaunch every
  session after upgrading. Check with:

  ```bash
  ps aux | grep '[o]pencode'
  stat -f '%z %i' ~/.opencode/bin/opencode      # compare against lsof -p <pid>
  ```

- **`auth.json` is left in place.** V2 copies it into SQLite but never writes back,
  and `opencode auth logout` only touches the DB. The stale file is harmless, but
  do not treat it as the source of truth for V2 credentials.

- **Never run `opencode uninstall` here.** V2's uninstall removes global config,
  data, cache and state shared across versions — and `~/.config/opencode/*.jsonc`
  are symlinks into this repo.

- **`cli.json` is only created by the TUI**, not by `opencode run`/`auth`/`mcp`.
  It is authored directly in this repo instead, so nothing needs to be migrated.

- **A missing top-level `model` breaks every run.** V2 ships a built-in `opencode`
  (Console) provider offering free models. With no explicit default, session model
  resolution picks it, finds no credential, and fails with
  `Integration.Authorization: Request failed: 401` — *before* any provider request,
  so the error does not mention Anthropic at all. Any run passing `--model`
  explicitly still works, which makes it look like a per-agent problem. Fix is the
  top-level `"model"` in `opencode.jsonc`.

- **`opencode run --agent <subagent>` does not use that agent's configured model.**
  Per the V2 agent docs, a session stores its model separately, and a subagent's
  `model` applies only when it is launched through the `subagent` tool. So
  `opencode run --agent explore` reports the *session* model. This is expected, not
  a broken override. To actually verify a subagent's model, delegate to it and read
  the child session back:

  ```bash
  sqlite3 "$(opencode debug paths db)" \
    "select data from session_message order by time_created desc limit 20;" \
    | grep -o '"agent":"[^"]*","model":{"id":"[^"]*"'
  ```

- **V2 `opencode models` takes no positional provider argument** (V1 did). Use
  `opencode models | grep '^anthropic/'`. There is also no `opencode agent`
  subcommand in V2.

- The server HTTP API is not at `/agent`, `/config`, etc. — those paths all return
  the web UI. Use the [API reference](https://opencode.ai/v2/docs/api); the service
  URL and basic-auth password come from `opencode service status` and
  `~/.config/opencode/service.json`.

---

## V1 → V2 config mapping

What changed in `opencode.jsonc`:

| V1                                  | V2                                                        |
| ----------------------------------- | --------------------------------------------------------- |
| `autoupdate: true`                  | `update: "auto"`                                          |
| `permission.<tool>.<pattern>`       | `permissions: [{action, resource, effect}]` (ordered array) |
| action `bash` / `task` / `write`    | `shell` / `subagent` / `edit`                             |
| `mcp.<name>`                        | `mcp.servers.<name>`                                      |
| `enabled: true`                     | omit (connects by default)                                |
| `enabled: false`                    | `disabled: true`                                          |
| `agent.<name>`                      | `agents.<name>`                                           |
| `agent.*.prompt` / `disable`        | `system` / `disabled`                                     |
| `provider.<id>.options.baseURL`     | `providers.<id>.settings.baseURL`                         |
| `plugin: [...]`                     | `plugins: [...]` — **V1 plugin code does not run in V2**   |
| `tui.json` (layered)                | `cli.json` (one global file)                              |

Permission patterns: V2's `*` matches `/` too, so V1's `/tmp/**` collapses to
`/tmp/*`. macOS canonicalises `/tmp` → `/private/tmp` before matching, so the
`/private/tmp` rules are the ones that actually fire there.

### Dropped plugins

| V1 plugin                    | V2 replacement                                              |
| ---------------------------- | ----------------------------------------------------------- |
| `@mohak34/opencode-notifier` | Built in: `attention.notifications` / `attention.sound` in `cli.json` |
| `opencode-claude-auth`       | CLIProxyAPI gateway (see above)                             |

Neither has a V2 build; both peer-depend on the V1 `@opencode-ai/plugin` package.
V2 plugins use `@opencode/plugin` with a different API (`Plugin.define({id, setup})`).

---

## Operations

```bash
brew services restart cliproxyapi                    # restart gateway
opencode service restart                             # restart opencode server
opencode service status                              # server URL
opencode debug paths                                 # config / data / db locations
cliproxyapi --config ~/.cli-proxy-api/config.yaml --claude-login   # re-auth Claude
```

If Anthropic starts returning 401/403, the usual causes are: the gateway is not
running (`lsof -nP -iTCP:8317 -sTCP:LISTEN`), the Claude OAuth token needs
refreshing (re-run `--claude-login`), or a saved Anthropic account reappeared in
`opencode auth list`.

## References

- opencode V2 docs: <https://opencode.ai/v2/docs>
- V1 → V2 migration guide: <https://opencode.ai/v2/docs/migrate-v1>
- Plugin migration: <https://opencode.ai/v2/docs/build/plugins/migrate-v1>
- CLIProxyAPI docs: <https://help.router-for.me/>
