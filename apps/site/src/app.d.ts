// See https://svelte.dev/docs/kit/types#app.d.ts
declare global {
  namespace App {
    // interface Error {}
    // interface Locals {}
    // interface PageData {}
    // interface PageState {}
    // interface Platform {}
  }
  // injected by vite.config.ts `define` at build time, shown in the footer
  const __SITE_VERSION__: string;
  const __GIT_SHA__: string;
  const __BUILD_DATE__: string;
}

export {};
