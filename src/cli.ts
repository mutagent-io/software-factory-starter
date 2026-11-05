#!/usr/bin/env bun
import { slugify, type SlugOptions } from './slug.ts';

const USAGE = `Usage: starter [options] <text...>

Turns text into a URL slug.

Options:
  -s, --separator <sep>  What joins the words (default "-")
      --keep-case        Do not lower-case the result
  -h, --help             Show this help

Examples:
  bun src/cli.ts "Hello, World!"          # hello-world
  bun src/cli.ts -s _ "Snake case please" # snake_case_please`;

/** The parsed command line: the text and its options, or a request for help. */
export type Parsed = { help: true } | { help: false; text: string; options: SlugOptions };

/** Parses argv (without the runtime and script). Throws on an unknown flag or a missing value. */
export function parseArgs(argv: string[]): Parsed {
  const options: SlugOptions = {};
  const words: string[] = [];
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i] as string;
    if (arg === '-h' || arg === '--help') return { help: true };
    if (arg === '-s' || arg === '--separator') {
      const value = argv[++i];
      if (value === undefined) throw new Error(`${arg} needs a value`);
      options.separator = value;
    } else if (arg === '--keep-case') {
      options.lowercase = false;
    } else if (arg.startsWith('-') && arg.length > 1) {
      throw new Error(`unknown option ${arg}`);
    } else {
      words.push(arg);
    }
  }
  if (words.length === 0) throw new Error('no text given');
  return { help: false, text: words.join(' '), options };
}

/** Runs the CLI; returns the exit code. */
export function main(argv: string[], out = console.log, err = console.error): number {
  try {
    const parsed = parseArgs(argv);
    if (parsed.help) {
      out(USAGE);
      return 0;
    }
    out(slugify(parsed.text, parsed.options));
    return 0;
  } catch (error) {
    err(`starter: ${error instanceof Error ? error.message : String(error)}`);
    err('Run starter --help for usage.');
    return 1;
  }
}

if (import.meta.main) process.exit(main(process.argv.slice(2)));
