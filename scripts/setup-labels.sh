#!/usr/bin/env bash
# setup-labels.sh <owner/repo> [trigger-label]
#
# Create the labels issue-driven-flow needs in a consumer repository. The
# trigger label defaults to "flow"; pass a second argument to use another
# name (it must not start with "flow/" — that prefix is the state-label
# namespace). Idempotent: existing labels are updated in place (--force),
# so check `gh label list` for a conflicting label of the same name
# before running. Requires an authenticated gh CLI with access to the
# target repository.
set -euo pipefail

repo="${1:?usage: setup-labels.sh <owner/repo> [trigger-label]}"
trigger="${2:-flow}"

case "$trigger" in
  flow/*)
    echo "ERROR: trigger label must not start with 'flow/' (reserved for state labels)" >&2
    exit 1 ;;
esac

create() {
  gh label create "$1" --repo "$repo" --color "$2" --description "$3" --force
}

create "$trigger" "6f42c1" \
  "Run the next issue-driven-flow step on this issue"

create "flow/shaping" "fbca04" \
  "issue-driven-flow: Composer is shaping this issue (automation-managed)"
create "flow/awaiting-approval" "1d76db" \
  "issue-driven-flow: shaped, waiting for human approval (automation-managed)"
create "flow/building" "a2eeef" \
  "issue-driven-flow: Crafter is implementing (automation-managed)"
create "flow/pr-open" "0052cc" \
  "issue-driven-flow: a PR is open for this issue (automation-managed)"
create "flow/blocked-shape" "d93f0b" \
  "issue-driven-flow: shaping blocked, needs human input (automation-managed)"
create "flow/blocked-build" "b60205" \
  "issue-driven-flow: implementation blocked, needs human input (automation-managed)"
create "flow/done" "0e8a16" \
  "issue-driven-flow: PR merged, flow complete (automation-managed)"
create "flow/split" "5319e7" \
  "issue-driven-flow: split into sub-issues, tracking only (automation-managed)"

echo "issue-driven-flow labels are set up in ${repo} (trigger label: ${trigger})."
