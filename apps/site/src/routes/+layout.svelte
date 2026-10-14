<script lang="ts">
  import '../app.css';
  import { page } from '$app/state';

  let { children } = $props();

  const repo = 'https://github.com/gobofx/gobofx';
  const onSpec = $derived(page.url.pathname.startsWith('/spec'));
  const onPlay = $derived(page.url.pathname.startsWith('/play'));
</script>

<div class="page">
  <nav>
    <a class="logo" href="/">
      <span class="logoMark" aria-hidden="true">◧</span>
      <span class="logoText">GOBOFX<span class="logoTld">.ORG</span></span>
    </a>
    <div class="navLinks">
      <a href="/spec" class:active={onSpec}>spec</a>
      <a href="/play" class:active={onPlay}>play</a>
      <a href="{repo}/blob/main/CATALOG.md" target="_blank" rel="noreferrer noopener">catalog</a>
      <a href={repo} target="_blank" rel="noreferrer noopener">GitHub</a>
    </div>
  </nav>

  <main>
    {@render children()}
  </main>

  <footer>
    <div>GOBOFX.ORG</div>
    <div class="footSep">·</div>
    <div>MIT OR Apache-2.0</div>
    <div class="footSep">·</div>
    <div><a href={repo} target="_blank" rel="noreferrer noopener">github.com/gobofx/gobofx</a></div>
    <div class="footSep">·</div>
    <div>{new Date().getFullYear()}</div>
    <div class="footSep">·</div>
    <div class="version" title="built {__BUILD_DATE__}">v{__SITE_VERSION__} · {__GIT_SHA__}</div>
  </footer>
</div>

<style>
  nav {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.5rem 0 2.5rem;
  }
  .logo {
    display: inline-flex;
    align-items: center;
    gap: 0.6rem;
    color: var(--text);
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 1.05rem;
    letter-spacing: 0.06em;
    border-bottom: none;
  }
  .logo:hover {
    color: var(--accent);
  }
  .logoMark {
    color: var(--accent-coral);
    font-size: 1.3rem;
    line-height: 1;
  }
  .logoTld {
    color: var(--text-dim);
  }
  .navLinks {
    display: flex;
    gap: 1.5rem;
    font-family: var(--font-mono);
    font-size: 0.85rem;
  }
  .navLinks a {
    color: var(--text-muted);
  }
  .navLinks a:hover,
  .navLinks a.active {
    color: var(--accent);
  }

  footer {
    margin-top: 4rem;
    padding-top: 2rem;
    border-top: 1px solid var(--border-soft);
    font-family: var(--font-mono);
    font-size: 0.78rem;
    color: var(--text-dim);
    display: flex;
    flex-wrap: wrap;
    gap: 0.6rem;
    align-items: center;
  }
  .footSep {
    color: var(--border);
  }

  @media (max-width: 540px) {
    nav {
      flex-wrap: wrap;
      gap: 0.75rem 1.25rem;
      padding-bottom: 1.75rem;
    }
    .navLinks {
      gap: 1rem;
      font-size: 0.78rem;
    }
  }
</style>
