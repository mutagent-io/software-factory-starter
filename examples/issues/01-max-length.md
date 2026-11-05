---
title: "Add --max-length: cut long slugs at a word boundary"
labels: [origin:user]
---

## What

Add a `maxLength` option to `slugify` and a `-m, --max-length <n>` flag to the CLI. A slug longer
than `n` characters is cut at the last separator that keeps it within `n`, so no word is split.

```bash
bun src/cli.ts --max-length 20 "The quick brown fox jumps over the lazy dog"
# the-quick-brown-fox
```

## Acceptance criteria

- [ ] `slugify(text, { maxLength: n })` returns a slug of at most `n` characters.
- [ ] The cut falls on a separator: `slugify('The quick brown fox jumps', { maxLength: 12 })` is `the-quick`.
- [ ] When the first word alone is longer than `n`, that word is cut to `n` characters
      (`slugify('Supercalifragilistic', { maxLength: 5 })` is `super`).
- [ ] The result never ends with a separator.
- [ ] `maxLength` must be a positive whole number; anything else throws a clear error, and the
      CLI exits 1 with `starter: --max-length must be a positive whole number`.
- [ ] Without `maxLength` nothing changes.
- [ ] `--help` and the README's usage list the new flag.
- [ ] Tests cover each line above; `bun run check` passes.
