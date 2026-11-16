#!/bin/bash
# Refuse to commit a template with a placeholder filled in, or your own values.
#
# Why this exists:
#   The manifests are templates. Your values live in .env, and
#   scripts/render.sh writes filled copies to build/. Both are git-ignored,
#   but `git add -f`, or filling a template in place, would still put your
#   names, license or keys in the repository. This checks the staged (index)
#   copies:
#   - every ${NAME} placeholder in a committed template must still be there,
#     so replacing ${DB2_INSTANCE_NAME} with dwdb, say, is blocked;
#   - the license and key placeholders must be there, even in a new template;
#   - nothing from .env or build/, and no .crt or .pem file, may be staged.
#
# Runs as the pre-commit hook (.githooks/pre-commit). Git never turns a hook
# on by itself, so enable it once in every clone:
#   git config core.hooksPath .githooks
#
# Usage (from the repository root):
#   ./scripts/check-placeholders.sh            # check the staged copies
#   ./scripts/check-placeholders.sh --worktree # check the files on disk
#
# If you mean to remove a placeholder, commit with --no-verify and say why in
# the commit message.

set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "${root}"

mode=${1:-index}

# file|placeholder, one per line
checks='templates/db2u-instance/db2u-instance.yaml|${DB2_LICENSE}
templates/ibm-backup-restore/backend-storage-location/secret.yaml|${S3_ACCESS_KEY_ID}
templates/ibm-backup-restore/backend-storage-location/secret.yaml|${S3_ACCESS_KEY}'

failed=0
reported=""

# The copy being checked: the staged one, or the one on disk.
current() {
  if [ "${mode}" = "--worktree" ]; then
    [ -f "$1" ] && cat "$1"
  else
    git show ":$1" 2>/dev/null
  fi
}
placeholders() { grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' | sort -u || true; }

# Every placeholder in the committed copy of a template must still be there.
# A renamed template is compared with the committed copy at its old path.
# (In --worktree mode git sees a rename only once the new file is staged.)
if git rev-parse -q --verify HEAD >/dev/null; then
  if [ "${mode}" = "--worktree" ]; then
    changes=$(git diff -M --name-status --diff-filter=MR HEAD -- 'templates/*.yaml')
  else
    changes=$(git diff --cached -M --name-status --diff-filter=MR HEAD -- 'templates/*.yaml')
  fi
  while IFS=$'\t' read -r status old new; do
    [ -n "${status}" ] || continue
    file=${new:-${old}}
    content=$(current "${file}") || continue
    gone=$(comm -23 <(git show "HEAD:${old}" 2>/dev/null | placeholders) <(placeholders <<<"${content}"))
    if [ -n "${gone}" ]; then
      echo "BLOCKED: ${file} no longer contains $(echo ${gone} | sed 's/ /, /g')" >&2
      reported="${reported} ${file}:$(echo ${gone} | tr ' ' :):"
      failed=1
    fi
  done <<<"${changes}"
fi

# The license and keys, checked even when a template is new.
while IFS='|' read -r file placeholder; do
  content=$(current "${file}") || continue
  [ -n "${content}" ] || continue
  case "${reported}" in *" ${file}:"*"${placeholder}:"*) continue ;; esac
  if ! grep -qF -- "${placeholder}" <<<"${content}"; then
    echo "BLOCKED: ${file} no longer contains ${placeholder}" >&2
    failed=1
  fi
done <<<"${checks}"

if [ "${mode}" != "--worktree" ]; then
  staged=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '^(\.env$|build/)|\.(crt|pem)$' || true)
  if [ -n "${staged}" ]; then
    echo "BLOCKED: these hold your own values and must not be committed:" >&2
    echo "${staged}" | sed 's/^/  /' >&2
    failed=1
  fi
fi

if [ "${failed}" -ne 0 ]; then
  echo >&2
  echo "Put the placeholder back, and keep your values in .env: ./scripts/render.sh fills them into build/." >&2
  echo "To unstage a file and keep it on disk:  git restore --staged <file>" >&2
  exit 1
fi
