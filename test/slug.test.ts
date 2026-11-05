import { describe, expect, test } from 'bun:test';
import { slugify } from '../src/slug.ts';
import { main, parseArgs } from '../src/cli.ts';

describe('slugify', () => {
  test('joins words with a dash and lower-cases them', () => {
    expect(slugify('Hello, World!')).toBe('hello-world');
  });

  test('collapses runs of spaces and punctuation into one separator', () => {
    expect(slugify('  Two   spaces -- and  dashes ')).toBe('two-spaces-and-dashes');
  });

  test('keeps digits', () => {
    expect(slugify('Release 2.0 notes')).toBe('release-2-0-notes');
  });

  test('returns an empty slug for text with no letters or digits', () => {
    expect(slugify('!!! ???')).toBe('');
  });

  test('takes a custom separator', () => {
    expect(slugify('Snake case please', { separator: '_' })).toBe('snake_case_please');
  });

  test('can keep the case', () => {
    expect(slugify('Hello World', { lowercase: false })).toBe('Hello-World');
  });

  test('refuses an empty separator or one with letters or digits', () => {
    expect(() => slugify('a b', { separator: '' })).toThrow('must not be empty');
    expect(() => slugify('a b', { separator: 'x' })).toThrow('letters or digits');
  });
});

describe('cli', () => {
  test('parses text and flags', () => {
    expect(parseArgs(['-s', '_', '--keep-case', 'Hello', 'World'])).toEqual({
      help: false,
      text: 'Hello World',
      options: { separator: '_', lowercase: false },
    });
  });

  test('prints the slug and exits 0', () => {
    const out: string[] = [];
    expect(main(['Hello, World!'], (line) => out.push(line))).toBe(0);
    expect(out).toEqual(['hello-world']);
  });

  test('prints usage for --help', () => {
    const out: string[] = [];
    expect(main(['--help'], (line) => out.push(line))).toBe(0);
    expect(out[0]).toStartWith('Usage: starter');
  });

  test('exits 1 with a message on an unknown option or no text', () => {
    const err: string[] = [];
    expect(main(['--nope', 'x'], () => {}, (line) => err.push(line))).toBe(1);
    expect(err[0]).toBe('starter: unknown option --nope');
    expect(main([], () => {}, () => {})).toBe(1);
  });
});
