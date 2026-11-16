# shellcheck shell=bash
# Helpers for .architech/factory/factory.yaml, sourced by setup-factory.sh (and test/setup-factory.test.ts).

# factory_has_placeholders FILE: succeeds when FILE still holds a shipped placeholder: YOUR_ORG or
# YOUR_REPO in any case, or Project 0. Comments are ignored, so the header that names them is fine.
# One awk over the whole file: no pipe, so no early exit that pipefail could misread.
factory_has_placeholders() {
  awk '
    { line = $0; sub(/^[[:space:]]*#.*/, "", line); sub(/[[:space:]]#.*$/, "", line) }
    tolower(line) ~ /your_(org|repo)/ { found = 1 }
    line ~ /(^|[{,[:space:]])project:[[:space:]]*0+[[:space:]]*([,}]|$)/ { found = 1 }
    END { exit !found }
  ' "$1"
}

# factory_fill FILE OWNER NUMBER REPO: prints FILE with boards.main.ref and repos[0].name filled in.
factory_fill() {
  sed -E \
    -e "s#^(    ref: \\{ owner: )[^,]+(, project: )[0-9]+( \\}.*)\$#\\1$2\\2$3\\3#" \
    -e "s#^(  - name: )[^ ]+\$#\\1$4#" \
    "$1"
}
