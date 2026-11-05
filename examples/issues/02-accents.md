---
title: "Accented letters are dropped: \"Crème brûlée\" becomes cr-me-br-l-e"
labels: [origin:user]
---

## What happens

`slugify` keeps only ASCII letters and digits, so any accented letter splits the word:

```bash
bun src/cli.ts "Crème brûlée"   # cr-me-br-l-e
bun src/cli.ts "Ångström"       # ngstr-m
```

## What should happen

Letters with accents become their plain ASCII letter before the slug is made:

```bash
bun src/cli.ts "Crème brûlée"   # creme-brulee
bun src/cli.ts "Ångström"       # angstrom
```

## Acceptance criteria

- [ ] Accented Latin letters become their base letter (`é → e`, `ü → u`, `ñ → n`, `Å → a`).
      Unicode normalization (NFKD, then dropping the combining marks) is the expected approach.
- [ ] These letters, which have no combining form, map as written: `ß → ss`, `æ → ae`, `ø → o`,
      `œ → oe`, `đ → d`, `ł → l`.
- [ ] Characters that still have no ASCII form (for example `日本`, emoji) are treated as
      separators, as today.
- [ ] `--keep-case` keeps the case of the converted letters (`Ångström → Angstrom`).
- [ ] No runtime dependency is added.
- [ ] Tests cover each line above; `bun run check` passes.
