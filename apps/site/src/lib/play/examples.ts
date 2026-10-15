// The reference plugins from spec/examples, bundled as raw text at build time.

const files = import.meta.glob('../../../../../spec/examples/*/*', {
  query: '?raw',
  import: 'default',
  eager: true
}) as Record<string, string>;

export type ExamplePlugin = {
  /** folder name, e.g. "cross-dissolve" */
  slug: string;
  manifest: string;
  shaders: Record<string, string>;
  name: string;
  kind: 'effect' | 'transition' | 'generator';
};

const byFolder = new Map<string, ExamplePlugin>();
for (const [path, source] of Object.entries(files)) {
  const m = path.match(/examples\/([^/]+)\/([^/]+)$/);
  if (!m) continue;
  const [, slug, file] = m;
  let entry = byFolder.get(slug);
  if (!entry) {
    entry = { slug, manifest: '', shaders: {}, name: slug, kind: 'effect' };
    byFolder.set(slug, entry);
  }
  if (file === 'manifest.json') {
    entry.manifest = source;
    try {
      const j = JSON.parse(source);
      entry.name = j.name ?? slug;
      entry.kind = j.kind === 'transition' || j.kind === 'generator' ? j.kind : 'effect';
    } catch {
      /* reported by the validator when loaded */
    }
  } else if (file.endsWith('.wgsl')) {
    entry.shaders[file] = source;
  }
}

export const examples: ExamplePlugin[] = [...byFolder.values()].sort((a, b) => a.name.localeCompare(b.name));
