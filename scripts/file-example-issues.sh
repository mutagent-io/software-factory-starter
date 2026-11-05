#!/usr/bin/env bash
# Files the example issues in examples/issues/*.md. Safe to run again: an issue whose title is
# already on the repo (open or closed) is skipped. It never adds factory:pickup; you do that.
#
#   scripts/file-example-issues.sh [--repo owner/name] [--project <number>] [--dry-run]
#
# --project adds each issue to the org Project (its Todo column); adding twice is a no-op.
# Without it the factory adds an issue to the board itself when you pick it up.
set -euo pipefail

REPO=""
PROJECT=""
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:?--repo needs owner/name}"; shift 2 ;;
    --project) PROJECT="${2:?--project needs the Project number}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "file-example-issues.sh: unknown argument $1" >&2; exit 1 ;;
  esac
done
cd "$(git rev-parse --show-toplevel)"
[ -n "$REPO" ] || REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"

for file in examples/issues/*.md; do
  # Front matter: title: "..." and labels: [a, b]; the body is everything after the second ---.
  title="$(sed -n 's/^title: "\(.*\)"$/\1/p' "$file" | head -n1 | sed 's/\\"/"/g')"
  labels="$(sed -n 's/^labels: \[\(.*\)\]$/\1/p' "$file" | head -n1 | tr -d ' ')"
  body="$(awk 'n >= 2 { print } /^---$/ { n++ }' "$file")"
  [ -n "$title" ] || { echo "skip $file: no title"; continue; }

  quoted="${title//\\/\\\\}"; quoted="${quoted//\"/\\\"}"   # for the jq string below
  url="$(gh issue list --repo "$REPO" --state all --limit 200 --json title,url \
    --jq ".[] | select(.title == \"$quoted\") | .url" | head -n1)"
  if [ -n "$url" ]; then
    echo "exists: $title ($url)"
  elif [ "$DRY_RUN" -eq 1 ]; then
    echo "would file: $title (labels: ${labels:-none})"
    continue
  else
    url="$(gh issue create --repo "$REPO" --title "$title" --body "$body" ${labels:+--label "$labels"})"
    echo "filed: $url"
  fi
  if [ -n "$PROJECT" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "would add to Project #$PROJECT: $url"
    else
      gh project item-add "$PROJECT" --owner "${REPO%%/*}" --url "$url" >/dev/null
      echo "on Project #$PROJECT: $url"
    fi
  fi
done
