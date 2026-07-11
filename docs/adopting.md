# Adopting github-flow in a repository

Two one-time steps: add a credential and create the labels — then drop in
one wrapper workflow.

`4moda/github-flow` is public, so its reusable workflows and actions are
usable from any repository as-is. (If you run a private fork instead, grant
access first: fork → **Settings → Actions → General → Access** →
*"Accessible from repositories owned by ..."*.)

## 1. Add a Claude credential

In the consumer repository (or the owning org), add **one** of:

- `ANTHROPIC_API_KEY` — an Anthropic API key, or
- `CLAUDE_CODE_OAUTH_TOKEN` — a Claude Code OAuth token (from
  `claude setup-token`, for Pro/Max subscriptions).

Optional: `GF_BOT_TOKEN` — a PAT (contents: write, pull-requests: write)
used for pushing and creating PRs. Without it the default `GITHUB_TOKEN` is
used, which works but **does not trigger the repository's own CI on the
PRs the Crafter opens** (GitHub suppresses workflow runs for events created
with `GITHUB_TOKEN`). Add this when you want CI results on Crafter PRs.

## 2. Create the labels

```bash
bash scripts/setup-labels.sh <owner>/<repo>
```

(From a checkout of this repository, with `gh` authenticated.) This creates
the public `ai` trigger label and the `flow/*` state labels. The state
labels also self-heal — workflows create them on demand — but `ai` must
exist so humans can add it.

## 3. Add the wrapper workflow

One file: `.github/workflows/github-flow.yml`

```yaml
name: github-flow

on:
  issues:
    types: [labeled]
  pull_request:
    types: [closed, reopened]
  pull_request_review:
    types: [submitted]

jobs:
  shape:
    if: github.event_name == 'issues' && github.event.label.name == 'ai'
    uses: 4moda/github-flow/.github/workflows/shape.yml@v1
    permissions:
      contents: read
      issues: write
    secrets:
      anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
      claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}

  build:
    if: github.event_name == 'issues' && github.event.label.name == 'ai'
    uses: 4moda/github-flow/.github/workflows/build.yml@v1
    permissions:
      contents: write
      issues: write
      pull-requests: write
    secrets:
      anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
      claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
      bot_token: ${{ secrets.GF_BOT_TOKEN }}

  sync-pr:
    if: github.event_name == 'pull_request' || github.event_name == 'pull_request_review'
    uses: 4moda/github-flow/.github/workflows/sync-pr.yml@v1
    permissions:
      issues: write
      pull-requests: read
```

Both `shape` and `build` receive every `ai` trigger; a shared, tested
routing table (`scripts/gf.py`) guarantees exactly one of them acts, so the
double wiring is safe.

Versioning: `@v1` is a moving major tag — it always points at the latest
compatible release, and the workflows' internal action references use the
same tag, so everything stays in lockstep. Pin an exact release (e.g.
`@v1.0.0`) if you want to control upgrades yourself, or `@main` to track
unreleased changes.

To override the model, pass `with: { model: claude-opus-4-8 }` (or another
model id) to `shape` and `build`.

## First run

1. Open an issue describing what you want, in your own words.
2. Add the `ai` label. The Composer rewrites the issue into the shaped
   template and the issue moves to `flow/awaiting-approval`.
3. Review the shaped issue. Edit freely. When you agree, tick
   **ready for implementation** and add `ai` again.
4. The Crafter pushes branch `flow/issue-<n>` and opens a PR that closes the
   issue. Review it.
   - Merge when satisfied — the issue closes and is marked `flow/done`.
   - Or request changes in a PR review and add `ai` on the issue to have
     the Crafter rework the same PR.

If a run gets blocked, the issue gets a `flow/blocked-*` label and a comment
listing exactly what is missing. Answer in the issue and add `ai` to
resume.

## What humans manage

Only the `ai` label and the `ready for implementation` checkbox. All
`flow/*` labels are automation-owned — never add or remove them by hand
(if labels were tampered with, the next `ai` run explains how to recover).

## Notes and limits

- The Crafter cannot modify `.github/workflows/` in the consumer repository
  unless `GF_BOT_TOKEN` has the `workflow` scope; the default token rejects
  such pushes.
- Runs are serialized per issue (`concurrency` group), so adding `ai`
  during a run queues an acknowledge rather than racing.
- Minimum permissions are declared per job in the wrapper above; nothing in
  the flow needs more.
- The `flow/*` label namespace and `flow/issue-*` branch namespace are
  reserved for github-flow — don't create your own labels or branches with
  those prefixes in a consumer repository.
