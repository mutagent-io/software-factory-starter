/** Options for {@link slugify}. */
export interface SlugOptions {
  /** What joins the words. Default `-`. */
  separator?: string;
  /** Lower-case the result. Default `true`. */
  lowercase?: boolean;
}

/**
 * Turns text into a URL slug: runs of anything that is not an ASCII letter or digit become one
 * separator, and separators at either end are dropped.
 *
 *   slugify('Hello, World!')            → 'hello-world'
 *   slugify('  Two   spaces ')          → 'two-spaces'
 *   slugify('Snake case', { separator: '_' }) → 'snake_case'
 */
export function slugify(input: string, options: SlugOptions = {}): string {
  const separator = options.separator ?? '-';
  const lowercase = options.lowercase ?? true;
  if (separator.length === 0) throw new Error('separator must not be empty');
  if (/[a-z0-9]/i.test(separator)) throw new Error('separator must not contain letters or digits');

  const text = lowercase ? input.toLowerCase() : input;
  const words = text.split(/[^a-z0-9]+/i).filter((word) => word.length > 0);
  return words.join(separator);
}
