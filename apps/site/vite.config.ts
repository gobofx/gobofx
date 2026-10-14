import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const pkg = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8')) as { version: string };
let sha = 'dev';
try {
  sha = execSync('git rev-parse --short HEAD', { encoding: 'utf8' }).trim();
} catch {
  /* not a git checkout */
}

export default defineConfig({
  plugins: [sveltekit()],
  define: {
    // shown in the footer so a deploy can be told apart from the last one
    __SITE_VERSION__: JSON.stringify(pkg.version),
    __GIT_SHA__: JSON.stringify(sha),
    __BUILD_DATE__: JSON.stringify(new Date().toISOString().slice(0, 10))
  },
  server: {
    // the play page imports spec/examples/* and the wasm host from the repo root
    fs: { allow: ['../..'] }
  }
});
