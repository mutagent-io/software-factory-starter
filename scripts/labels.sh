#!/usr/bin/env bash
# Creates (or updates) the labels the Factory reads, with their colours and descriptions.
# Idempotent: `gh label create --force` updates a label that already exists. Deletes nothing.
#
#   scripts/labels.sh                       # the repo of this checkout's origin
#   scripts/labels.sh --repo my-org/my-repo
#   scripts/labels.sh --dry-run             # print the commands, change nothing
#
# The vocabulary: one prefix per purpose.
#   factory:  starts or steers a run     (TRIGGER, a person)
#   merge:    controls merging           (GATE, a person)
#   origin:   who opened the item        (VISIBILITY only; nothing acts on it)
# "a person with write access" is enforced by the server: a label added by a bot or an App does
# not authorize anything.
set -euo pipefail

REPO=""
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:?--repo needs owner/name}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "labels.sh: unknown argument $1" >&2; exit 1 ;;
  esac
done

if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
fi

# name | colour | description (GitHub caps descriptions at 100 characters)
LABELS=(
  "factory:pickup|1D76DB|Start a factory run: the architect plans this issue. Added by a person."
  "factory:approved|0E8A16|Approve the factory's plan; the build starts. A person with write access."
  "factory:changes|FBCA04|Re-plan: comment what to change, then add this. A person with write access."
  "merge:ready|0E8A16|The factory may merge this reviewed PR. A person with write access; never an agent."
  "merge:hold|B60205|Stop: blocks pickup and every merge while present. Beats every other label."
  "merge:yolo|D93F0B|Merge without approval or review evidence, never past a hold. Write access."
  "origin:agent|C5DEF5|Opened by an agent (visibility only)."
  "origin:user|BFD4F2|Opened by a person (visibility only)."
)

for row in "${LABELS[@]}"; do
  IFS='|' read -r name color description <<<"$row"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'gh label create %q --repo %q --color %s --description %q --force\n' \
      "$name" "$REPO" "$color" "$description"
  else
    gh label create "$name" --repo "$REPO" --color "$color" --description "$description" --force >/dev/null
    echo "label ok: $name"
  fi
done
