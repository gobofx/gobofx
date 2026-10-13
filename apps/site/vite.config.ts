import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [sveltekit()],
  server: {
    // the play page imports spec/examples/* and the wasm host from the repo root
    fs: { allow: ['../..'] }
  }
});
