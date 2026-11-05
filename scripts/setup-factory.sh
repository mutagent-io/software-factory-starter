#!/usr/bin/env bash
# Sets up the Mutagent Software Factory for this repository. Safe to run again: every step checks
# first and changes only what is missing.
#
#   scripts/setup-factory.sh --dry-run   # read everything, print what it would change, change nothing
#   scripts/setup-factory.sh             # GitHub side: labels, the org Project and its Status columns,
#                                        # and factory.yaml filled in for your org and Project
#   scripts/setup-factory.sh --push      # also the Mutagent side: validate, push and enable the factory
#
# Options:
#   --repo <owner/name>       default: this checkout's GitHub origin
#   --project-title <title>   default: "Software Factory Starter"
#   --factory-file <path>     default: .architech/factory/factory.yaml
#
# Needs: gh (signed in with the repo and project scopes: gh auth refresh -s project), bun, and for
# --push the architech CLI signed in (architech factory login).
# shellcheck disable=SC2016  # the GraphQL queries and bun snippets are meant to stay unexpanded
set -euo pipefail

REPO=""
TITLE="Software Factory Starter"
FILE=".architech/factory/factory.yaml"
DRY_RUN=0
PUSH=0
APP_SLUG="mutagent"
COLUMNS=("Todo" "In Progress" "In Review" "Done")

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:?--repo needs owner/name}"; shift 2 ;;
    --project-title) TITLE="${2:?--project-title needs a title}"; shift 2 ;;
    --factory-file) FILE="${2:?--factory-file needs a path}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --push) PUSH=1; shift ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "setup-factory.sh: unknown argument $1" >&2; exit 1 ;;
  esac
done

cd "$(git rev-parse --show-toplevel)"
say()  { printf '\n== %s\n' "$*"; }
ok()   { printf '   ok: %s\n' "$*"; }
todo() { printf '   would: %s\n' "$*"; }
die()  { printf '\nsetup-factory.sh: %s\n' "$*" >&2; exit 1; }
# Reads one field (a.b.c) from JSON on stdin; prints nothing when it is absent.
field() { bun -e 'const d = JSON.parse(await Bun.stdin.text()); let v = d; for (const k of process.argv[1].split(".")) v = v?.[k]; if (v !== undefined && v !== null) console.log(typeof v === "object" ? JSON.stringify(v) : v);' "$1"; }

# ── 0. Preflight ───────────────────────────────────────────────────────────────────────────────
say "Preflight"
command -v gh >/dev/null || die "gh is not installed: https://cli.github.com"
command -v bun >/dev/null || die "bun is not installed: curl -fsSL https://bun.sh/install | bash"
GH_USER="$(gh api user --jq .login 2>/dev/null)" || die "gh is not signed in: gh auth login"
[ -f "$FILE" ] || die "no $FILE here"
if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" ||
    die "this checkout has no GitHub origin; pass --repo owner/name"
fi
OWNER="${REPO%%/*}"
OWNER_TYPE="$(gh api "users/$OWNER" --jq .type)"
[ "$OWNER_TYPE" = "Organization" ] ||
  die "$OWNER is a $OWNER_TYPE account. The cloud Factory works only on Projects owned by an organization: move the repo to an org."
ok "repo $REPO (organization $OWNER), gh user $GH_USER"

# ── 1. The Mutagent GitHub App on the org ─────────────────────────────────────────────────────
say "GitHub App '$APP_SLUG' on $OWNER"
SELECTION="$(gh api "orgs/$OWNER/installations" --jq ".installations[] | select(.app_slug == \"$APP_SLUG\") | .repository_selection" 2>/dev/null || true)"
case "$SELECTION" in
  all) ok "installed, all repositories" ;;
  selected) ok "installed on selected repositories: make sure $REPO is one of them (https://github.com/organizations/$OWNER/settings/installations)" ;;
  *) printf '   not found (or you are not an org admin). Install it on %s, with access to %s:\n     https://github.com/apps/%s/installations/new\n' "$OWNER" "$REPO" "$APP_SLUG" ;;
esac

# ── 2. Labels ─────────────────────────────────────────────────────────────────────────────────
say "Labels on $REPO"
if [ "$DRY_RUN" -eq 1 ]; then
  existing="$(gh label list --repo "$REPO" --limit 200 --json name --jq '.[].name')"
  for name in factory:pickup factory:approved factory:changes merge:ready merge:hold merge:yolo origin:agent origin:user; do
    if grep -qx "$name" <<<"$existing"; then ok "$name (would refresh its colour and description)"; else todo "create $name"; fi
  done
else
  scripts/labels.sh --repo "$REPO"
fi

# ── 3. The org Project and its Status columns ─────────────────────────────────────────────────
say "Project \"$TITLE\" owned by $OWNER"
NUMBER="$(gh project list --owner "$OWNER" --limit 100 --format json --jq ".projects[] | select(.title == \"$TITLE\" and .closed == false) | .number" | head -n1)" ||
  die "cannot list $OWNER's Projects: run gh auth refresh -s project"
if [ -z "$NUMBER" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    todo "gh project create --owner $OWNER --title \"$TITLE\""
    todo "add the Status column \"In Review\" (a new Project has Todo, In Progress, Done)"
    todo "gh project link <number> --owner $OWNER --repo ${REPO#*/}"
    todo "write board.ref { owner: $OWNER, project: <number> } and repos[0].name: $REPO into $FILE"
  else
    NUMBER="$(gh project create --owner "$OWNER" --title "$TITLE" --format json --jq .number)"
    ok "created Project #$NUMBER"
  fi
else
  ok "exists: #$NUMBER"
fi

if [ -n "$NUMBER" ]; then
  PROJECT_ID="$(gh project view "$NUMBER" --owner "$OWNER" --format json --jq .id)"
  FIELD_ID="$(gh project field-list "$NUMBER" --owner "$OWNER" --format json --jq '.fields[] | select(.name == "Status") | .id')"
  [ -n "$FIELD_ID" ] || die "Project #$NUMBER has no Status field"
  STATUS_JSON="$(gh api graphql -f query='query($id: ID!) { node(id: $id) { ... on ProjectV2SingleSelectField { options { id name color description } } } }' \
    -f id="$FIELD_ID" --jq '.data.node')"
  # Every option the field has, plus the missing columns, in board order; existing ids are kept so
  # items keep their status.
  BODY="$(STATUS="$STATUS_JSON" FIELD="$FIELD_ID" bun -e '
    const status = JSON.parse(process.env.STATUS);
    const wanted = ["Todo", "In Progress", "In Review", "Done"];
    const colors = { "Todo": "GRAY", "In Progress": "YELLOW", "In Review": "PURPLE", "Done": "GREEN" };
    const have = status.options ?? [];
    const missing = wanted.filter((n) => !have.some((o) => o.name === n));
    if (missing.length === 0) process.exit(0);
    const keep = have.map((o) => ({ id: o.id, name: o.name, color: o.color, description: o.description ?? "" }));
    const add = missing.map((n) => ({ name: n, color: colors[n], description: "" }));
    const order = (o) => { const i = wanted.indexOf(o.name); return i === -1 ? wanted.length : i; };
    const options = [...keep, ...add].sort((a, b) => order(a) - order(b));
    console.log(JSON.stringify({
      missing: missing.join(", "),
      body: {
        query: "mutation($f: ID!, $o: [ProjectV2SingleSelectFieldOptionInput!]) { updateProjectV2Field(input: { fieldId: $f, singleSelectOptions: $o }) { projectV2Field { ... on ProjectV2SingleSelectField { options { name } } } } }",
        variables: { f: process.env.FIELD, o: options },
      },
    }));
  ')"
  if [ -z "$BODY" ]; then
    ok "Status columns: ${COLUMNS[*]}"
  elif [ "$DRY_RUN" -eq 1 ]; then
    todo "add Status columns: $(field missing <<<"$BODY")"
  else
    field body <<<"$BODY" | gh api graphql --input - >/dev/null
    ok "added Status columns: $(field missing <<<"$BODY")"
  fi

  LINKED="$(gh api graphql -f query='query($o: String!, $r: String!) { repository(owner: $o, name: $r) { projectsV2(first: 50) { nodes { id } } } }' \
    -f o="$OWNER" -f r="${REPO#*/}" --jq '.data.repository.projectsV2.nodes[].id' | grep -cx "$PROJECT_ID" || true)"
  if [ -n "$LINKED" ] && [ "$LINKED" != "0" ]; then
    ok "linked to $REPO"
  elif [ "$DRY_RUN" -eq 1 ]; then
    todo "gh project link $NUMBER --owner $OWNER --repo ${REPO#*/}"
  else
    gh project link "$NUMBER" --owner "$OWNER" --repo "${REPO#*/}" >/dev/null
    ok "linked to $REPO"
  fi

  # ── 4. factory.yaml: this org, this Project, this repo ────────────────────────────────────────
  say "$FILE"
  TMP="$(mktemp)"
  sed -E \
    -e "s#^(    ref: \\{ owner: )[^,]+(, project: )[0-9]+( \\}.*)\$#\\1$OWNER\\2$NUMBER\\3#" \
    -e "s#^(  - name: )[^ ]+\$#\\1$REPO#" \
    "$FILE" >"$TMP"
  if cmp -s "$FILE" "$TMP"; then
    ok "already names $OWNER, Project #$NUMBER and $REPO"
    rm -f "$TMP"
  elif [ "$DRY_RUN" -eq 1 ]; then
    todo "update it:"; diff -u "$FILE" "$TMP" | sed 's/^/     /' || true; rm -f "$TMP"
  else
    mv "$TMP" "$FILE"
    ok "updated: commit and push it (git add $FILE && git commit -m 'factory: our board' && git push)"
  fi
fi

# ── 5. The Mutagent side ──────────────────────────────────────────────────────────────────────
if [ "$PUSH" -eq 0 ]; then
  say "Next: the Mutagent side (or run again with --push)"
  cat <<EOF
   architech factory login --json                       # once
   architech factory status --json                      # GitHub must show as connected for $OWNER
   architech factory push $FILE --dry-run --json
   architech factory push $FILE --json
   architech factory enable <metadata.name> --json
EOF
  exit 0
fi

say "Mutagent workspace"
command -v architech >/dev/null || die "the architech CLI is not installed"
STATUS="$(architech factory status --json)" || die "not signed in: architech factory login"
SITES="$(field data.integrations <<<"$STATUS")"
grep -qi "\"site\":\"$OWNER\"" <<<"$SITES" ||
  die "this workspace's GitHub connection is not $OWNER ($SITES). In the Mutagent app: Configuration > Integrations > GitHub > Connect (or 'Claim an existing GitHub installation'), pick $OWNER, then run again."
ok "GitHub connected: $OWNER"

VALID="$(architech factory validate "$FILE" --json)" || die "factory.yaml is not valid: $VALID"
FACTORY="$(field data.factoryId <<<"$VALID")"
DIGEST="$(field data.digest <<<"$VALID")"
CURRENT="$(architech factory show "$FACTORY" --json 2>/dev/null | field data.factory.current.digest || true)"
if [ "$CURRENT" = "$DIGEST" ]; then
  ok "factory $FACTORY is already at this file ($DIGEST)"
elif [ "$DRY_RUN" -eq 1 ]; then
  architech factory push "$FILE" --dry-run --json >/dev/null && todo "push $FILE (dry run passed)"
else
  architech factory push "$FILE" --dry-run --json >/dev/null || die "the dry run failed: architech factory push $FILE --dry-run --json"
  architech factory push "$FILE" --json >/dev/null
  ok "pushed $FACTORY"
fi

FSTATUS="$(architech factory status --json)"
ENABLED="$(bun -e 'const d = JSON.parse(process.argv[1]); const f = d.data.factories.find((x) => x.slug === process.argv[2]); console.log(f ? `${f.enabled} ${f.board?.bound ?? false}` : "absent absent");' "$FSTATUS" "$FACTORY")"
case "$ENABLED" in
  "true true") ok "enabled, board bound" ;;
  absent*)
    if [ "$DRY_RUN" -eq 1 ]; then todo "board bind + enable $FACTORY after the push"
    else die "factory $FACTORY not found after the push"; fi ;;
  *)
    if [ "$DRY_RUN" -eq 1 ]; then todo "board bind / enable $FACTORY ($ENABLED)"; else
      [ "${ENABLED#* }" = "true" ] || architech factory board bind "$FACTORY" --json >/dev/null
      [ "${ENABLED%% *}" = "true" ] || architech factory enable "$FACTORY" --json >/dev/null
      ok "board bound and factory enabled"
    fi ;;
esac

if [ "$DRY_RUN" -eq 1 ]; then
  say "Dry run done: nothing was changed"
else
  say "Ready"
  echo "   Label an issue factory:pickup and watch: architech factory runs list --json"
fi
