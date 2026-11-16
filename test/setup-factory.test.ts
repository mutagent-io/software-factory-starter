import { afterAll, describe, expect, test } from 'bun:test';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// The placeholder check and the rewrite that scripts/setup-factory.sh runs, against fixture copies
// of the shipped factory.yaml.
const SHIPPED = readFileSync('.architech/factory/factory.yaml', 'utf8');
const dir = mkdtempSync(join(tmpdir(), 'factory-file-'));
afterAll(() => rmSync(dir, { recursive: true, force: true }));

function run(script: string, ...args: string[]) {
  const proc = Bun.spawnSync(['bash', '-c', `. scripts/factory-file.sh && ${script}`, 'test', ...args]);
  return { code: proc.exitCode, out: proc.stdout.toString() };
}

function fixture(name: string, text: string): string {
  const path = join(dir, name);
  writeFileSync(path, text);
  return path;
}

const hasPlaceholders = (text: string, name: string) =>
  run('factory_has_placeholders "$1"', fixture(name, text)).code === 0;

const fill = (text: string, name: string) =>
  run('factory_fill "$1" "$2" "$3" "$4"', fixture(name, text), 'acme', '7', 'acme/factory-demo').out;

describe('factory_has_placeholders', () => {
  test('refuses the shipped file', () => {
    expect(hasPlaceholders(SHIPPED, 'shipped.yaml')).toBe(true);
  });

  test('accepts a filled-in file whose header comment still names the placeholders', () => {
    const filled = fill(SHIPPED, 'to-fill.yaml');
    expect(filled).toContain('# It ships with placeholders (YOUR_ORG, project 0, YOUR_ORG/YOUR_REPO)');
    expect(hasPlaceholders(filled, 'filled.yaml')).toBe(false);
  });

  test('refuses a filled-in file still on project 0', () => {
    const projectZero = fill(SHIPPED, 'to-fill-0.yaml').replace('project: 7', 'project: 0');
    expect(projectZero).toContain('ref: { owner: acme, project: 0 }');
    expect(hasPlaceholders(projectZero, 'project-zero.yaml')).toBe(true);
  });

  test('refuses a half-filled file: board filled in, repo name still the upper-case placeholder', () => {
    const halfFilled = SHIPPED.replace('ref: { owner: YOUR_ORG, project: 0 }', 'ref: { owner: acme, project: 7 }');
    expect(halfFilled).toContain('  - name: YOUR_ORG/YOUR_REPO\n');
    expect(hasPlaceholders(halfFilled, 'half-filled.yaml')).toBe(true);
  });

  test('accepts a filled-in file with a trailing comment naming a placeholder', () => {
    const commented = fill(SHIPPED, 'to-fill-comment.yaml').replace(
      '  - name: acme/factory-demo\n',
      '  - name: acme/factory-demo  # was YOUR_ORG/YOUR_REPO\n',
    );
    expect(commented).toContain('# was YOUR_ORG/YOUR_REPO');
    expect(hasPlaceholders(commented, 'trailing-comment.yaml')).toBe(false);
  });

  test('refuses lower-case placeholders', () => {
    const lower = SHIPPED.replace('ref: { owner: YOUR_ORG, project: 0 }', 'ref: { owner: acme, project: 7 }')
      .replace('name: YOUR_ORG/YOUR_REPO', 'name: your_org/your_repo');
    expect(hasPlaceholders(lower, 'lower.yaml')).toBe(true);
  });
});

describe('factory_fill', () => {
  test('replaces the board ref and the repo name, and nothing else', () => {
    const filled = fill(SHIPPED, 'fill.yaml');
    const expected = SHIPPED.replace('ref: { owner: YOUR_ORG, project: 0 }', 'ref: { owner: acme, project: 7 }')
      .replace('  - name: YOUR_ORG/YOUR_REPO', '  - name: acme/factory-demo');
    expect(filled).toBe(expected);
    expect(fill(filled, 'refill.yaml')).toBe(filled);
  });
});
