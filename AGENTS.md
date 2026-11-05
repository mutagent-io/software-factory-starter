# AGENTS.md

Instructions for any coding agent working in this repository, including the Mutagent Software
Factory's architect, developer and reviewer.

## The project

The example app is a tiny TypeScript CLI that turns text into URL slugs. It runs on Bun and has no
runtime dependencies.

| Path | What it is |
|---|---|
| `src/slug.ts` | `slugify(input, options)`, the library function |
| `src/cli.ts` | the command line: `parseArgs` and `main` |
| `test/slug.test.ts` | the tests (`bun:test`) |
| `.architech/factory/factory.yaml` | the Factory definition: board, labels, merge policy, triggers |

## Commands

```bash
bun install --frozen-lockfile   # dependencies (dev only)
bun run typecheck               # tsc --noEmit
bun test                        # the tests
bun run check                   # both; CI runs the same
bun src/cli.ts "Hello, World!"  # try it: hello-world
```

## Rules

- Every behaviour change comes with a test in `test/`. Write the failing test first.
- `bun run check` passes before you open or update a pull request.
- Keep it dependency-free at runtime. Ask before adding any package.
- Keep `--help` in `src/cli.ts` and the README's usage section in step with the flags.
- One issue, one pull request. Name the issue in the PR body (`Closes #N`).
- Do not edit `.architech/factory/factory.yaml` or `.github/` as part of a feature.
