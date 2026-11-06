# gobofx

Open standard for portable video effects and transitions: a JSON manifest
plus WGSL shaders, running identically in native wgpu hosts and in the
browser via WebGPU. Home page: <https://gobofx.org>. Dual licensed MIT OR
Apache-2.0; contributions need a DCO sign-off (`git commit -s`).

## Repo layout

```
gobofx/
├── apps/
│   └── site/        # gobofx.org — SvelteKit 5 (runes) on a Cloudflare Worker
├── spec/            # the standard: manifest.md, manifest.schema.json, shader-abi.md,
│   │                #   prelude.wgsl, examples/ (conformance set: one minimal plugin per kind)
├── plugins/         # the open-source plugin library — one folder per plugin, named by id
│   │                #   (org.gobofx.*), the catalogue's Core/Planned waves; see plugins/README.md
├── crates/          # reference Rust crate (parse, validate, wrap, params layout)
├── pnpm-workspace.yaml
└── CLAUDE.md        # this file
```

## ⚠️ Secrets policy — this repo is PUBLIC

**Never commit secrets, credentials, or sensitive identifiers.** Anything
pushed here is world-readable forever (git history is permanent; rewriting
it after a leak is not a fix).

Do **not** commit: `.env*`, `.dev.vars*`, API keys, tokens, signing keys,
Cloudflare account ids, Worker secrets, R2/KV credentials, private keys or
certificates, personal access tokens.

Where credentials belong: Cloudflare → `wrangler secret put <NAME>` or the
dashboard, never inline in `wrangler.jsonc`; local dev → `.dev.vars` or
`.env.local` (gitignored); CI → GitHub Actions secrets.

Before committing: `git diff --cached | grep -iE 'secret|token|api[_-]?key|password|bearer|private[_-]?key|account_id'`.

## Stack

- **pnpm** workspace (`apps/*`), `packageManager` pinned in `package.json`.
- **SvelteKit 5** with runes (`$state`, `$derived`, `$props`) — never the
  legacy `$:` / `export let` syntax.
- **Cloudflare Workers** via `@sveltejs/adapter-cloudflare`; `wrangler.jsonc`
  holds non-secret settings only (no `account_id` — the deploying account is
  whatever `wrangler login` is signed into).

## Common commands

```sh
pnpm install
pnpm dev                                  # vite dev for the site
pnpm build                                # vite build (adapter-cloudflare)
pnpm check                                # svelte-check, must be clean
pnpm --filter @gobofx/site preview        # wrangler dev on the built worker
pnpm --filter @gobofx/site run deploy         # build + wrangler deploy (only when asked)
```

## Deploying gobofx.org

The site lives in a dedicated Cloudflare account; its id is not in this repo. Because this repo
is public, `wrangler.jsonc` carries no `account_id`; the deploying account is
selected by `CLOUDFLARE_ACCOUNT_ID` from the gitignored `.env` at the repo
root (template: `.env.example`). The wrangler login sees more than one
account, so without it a non-interactive deploy stops to ask.

```sh
set -a && . ./.env && set +a && pnpm --filter @gobofx/site run deploy
```

Deploy only from a clean, committed `main`, and only when Mat says so. The
`gobofx.org` zone must exist in the same account for the custom-domain routes
in `wrangler.jsonc` to attach.

## Verifying plugins (do this before every commit that touches a plugin)

`tools/verify-all.sh [plugins/<id> …]` builds the CLI and runs `gobofx verify`,
which renders a case matrix derived from each manifest and checks the
contracts (transition endpoints, every param live, finite output,
determinism). It needs a GPU adapter; on a Linux box without one, the script
sources `tools/gpu-env.sh`, which points wgpu at SwiftShader (bundled with
Playwright's Chromium, or `$SWIFTSHADER_DIR`). Per plugin it writes
`dist/verify/report.json` and `dist/verify/sheet.png` — read the JSON, look at
the sheet. `ASSETS=1` also regenerates `icon.png`/`preview.png` from the
default render. Details: `crates/gobofx/README.md`.

## Conventions

- Deploy only when explicitly asked; never from an uncommitted tree.
- The site describes the standard; the normative text lives in `spec/`.
  When the two disagree, `spec/` wins and the site gets fixed.
- Dark theme by default. No third-party trackers.
- This project is independent of any host application. Do not mention,
  link or describe specific hosts, their products or their internals anywhere
  in this repo; keep host-specific behaviour (project documents, catalogs,
  billing) out of it.
