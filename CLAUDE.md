# wispfx

Open standard for portable video effects and transitions: a JSON manifest
plus WGSL shaders, running identically in native wgpu hosts and in the
browser via WebGPU. Home page: <https://wispfx.org>. Dual licensed MIT OR
Apache-2.0; contributions need a DCO sign-off (`git commit -s`).

## Repo layout

```
wispfx/
├── apps/
│   └── site/        # wispfx.org — SvelteKit 5 (runes) on a Cloudflare Worker
├── spec/            # the standard: manifest.md, manifest.schema.json, shader-abi.md,
│   │                #   prelude.wgsl, examples/ (reference plugins, naga-validated)
├── crates/          # reference Rust crate (parse, validate, wrap, params layout) — later
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
pnpm --filter @wispfx/site preview        # wrangler dev on the built worker
pnpm --filter @wispfx/site deploy         # build + wrangler deploy (only when asked)
```

## Deploying wispfx.org

The site lives in the **Cf@etiamo.com** Cloudflare account. Because this repo
is public, `wrangler.jsonc` carries no `account_id`; the deploying account is
selected by `CLOUDFLARE_ACCOUNT_ID` from the gitignored `.env` at the repo
root (template: `.env.example`). The wrangler login sees more than one
account, so without it a non-interactive deploy stops to ask.

```sh
set -a && . ./.env && set +a && pnpm --filter @wispfx/site deploy
```

Deploy only from a clean, committed `main`, and only when Mat says so. The
`wispfx.org` zone must exist in the same account for the custom-domain routes
in `wrangler.jsonc` to attach.

## Conventions

- Deploy only when explicitly asked; never from an uncommitted tree.
- The site describes the standard; the normative text lives in `spec/`.
  When the two disagree, `spec/` wins and the site gets fixed.
- Dark theme by default. No third-party trackers.
- Plinken is the first host implementation, not the owner of the format:
  keep host-specific behaviour (project documents, catalogs, billing) out of
  this repo.
