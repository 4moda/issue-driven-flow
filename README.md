# github-flow

Issue-driven AI development for GitHub, shared across repositories.

Humans steer with **one label and one checkbox**: add `ai` to an issue to
run the next automated step; tick `ready for implementation` to approve
implementation. Claude runs inside GitHub Actions — the **Composer** shapes
raw issues into implementable specs, the **Crafter** implements approved
issues as pull requests. **Merging is always a human action.** Internal
`flow/*` state labels are managed entirely by automation.

```mermaid
stateDiagram-v2
    [*] --> Raw : issue created
    Raw --> Shaping : + ai
    Shaping --> AwaitingApproval : shaped
    Shaping --> BlockedShape : needs input
    BlockedShape --> Shaping : answer + ai
    AwaitingApproval --> Shaping : + ai (box unticked)
    AwaitingApproval --> Building : box ticked + ai
    Building --> PrOpen : PR opened/updated
    Building --> BlockedBuild : needs input
    BlockedBuild --> Building : answer + ai
    PrOpen --> Building : rework + ai
    PrOpen --> Done : human merges
    PrOpen --> BlockedBuild : PR closed unmerged
    Done --> [*]
```

## Use it in a repository

One wrapper workflow, one credential, one label-setup run. See
[docs/adopting.md](docs/adopting.md).

## How it works

- [skills/github-flow/SKILL.md](skills/github-flow/SKILL.md) — operating
  model, roles, design rules.
- [skills/github-flow/references/concepts.md](skills/github-flow/references/concepts.md)
  — state machine, routing table, invariants, edge cases.
- [skills/github-flow/references/composer.md](skills/github-flow/references/composer.md)
  / [crafter.md](skills/github-flow/references/crafter.md) — the fixed
  contracts the agents follow.

## Layout

| Path | Purpose |
|------|---------|
| `.github/workflows/shape.yml` | reusable workflow: shape an issue (Composer) |
| `.github/workflows/build.yml` | reusable workflow: implement an issue (Crafter) |
| `.github/workflows/sync-pr.yml` | reusable workflow: mirror PR outcomes to the issue |
| `.github/workflows/ci.yml` | tests + lint for this repository |
| `actions/route` | shared routing decision (wraps `scripts/gf.py`) |
| `actions/build-context` | collect issue/PR/repo context for agent runs |
| `actions/update-issue` | the only writer of `flow/*` labels, bodies, comments |
| `scripts/gf.py` | tested decision logic (state, ready checkbox, routing) |
| `scripts/setup-labels.sh` | create the `ai` + `flow/*` labels in a consumer repo |
| `skills/github-flow/` | skill document and agent contracts |
| `tests/` | unit tests for `gf.py` |

Reusable workflows live under `.github/workflows/` (a GitHub requirement
for `workflow_call`), not the `workflows/` directory originally sketched in
issue #1.

## Development

```bash
python3 -m unittest discover -s tests   # unit tests
pipx run ruff check scripts tests       # python lint
shellcheck scripts/*.sh                 # shell lint
actionlint                              # workflow lint
```

CI runs all four on every push and pull request.

## Releasing

Consumers pin `@v1`, and the workflows' internal action references also use
`@v1`, so a release is: tag an exact version, then move the major tag to the
same commit.

```bash
git tag -a v1.1.0 -m "v1.1.0"
git tag -f v1 v1.1.0
git push origin v1.1.0
git push -f origin v1
```

Breaking changes (label names, result.json schema, wrapper inputs/secrets)
get a new major tag (`v2`) instead of moving `v1`.
