---
name: deploy
description: 'Deploy projects via GitHub Actions. Ensures current branch is merged into default branch before triggering workflow_dispatch. Auto-discovers deploy workflows from .github/workflows/. When multiple environments exist, defaults to non-production unless user explicitly requests prod. Use when user says "deploy", "部署", or similar.'
license: MIT
allowed-tools: Bash
---

# Deploy via GitHub Actions

## Overview

Deploy the current project by triggering a `workflow_dispatch` GitHub Actions workflow on the default branch. Handles PR merging, workflow discovery, and multi-environment selection.

## Workflow

### 1. Ensure current branch is on the default branch

```bash
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
CURRENT_BRANCH=$(git branch --show-current)
```

**If current branch ≠ default branch:**

- Check for an open PR:
  ```bash
  gh pr list --head "$CURRENT_BRANCH" --json number,state --jq '.[0]'
  ```
- If PR exists and is open → merge it:
  ```bash
  gh pr merge <number> --squash --delete-branch
  ```
- If no PR exists → ask the user what to do (create PR first, or abort).

**If current branch = default branch:**

- Check for unpushed commits (`git status`) and push if needed.

### 2. Discover deploy workflow

Do NOT assume the workflow filename. Search for `workflow_dispatch` triggers:

```bash
grep -rl 'workflow_dispatch' .github/workflows/ 2>/dev/null
```

**Single workflow found** → use it directly.

**Multiple workflows found** → apply environment selection rules (see below).

**No workflow found** → inform the user that no deployable workflow exists.

### 3. Environment selection (multi-workflow)

When multiple `workflow_dispatch` workflows exist, determine the target environment by inspecting workflow filenames, `name:` fields, and environment references (`environment:`, env var names, etc.):

| User intent | Keywords | Action |
|---|---|---|
| Default (no specific env mentioned) | "deploy", "部署" | Choose the **non-production** workflow (staging, dev, preview, etc.) |
| Production | "deploy prod", "部署生产", "deploy production" | Choose the **production** workflow |

If the environment is still ambiguous after inspection, ask the user to choose.

### 4. Trigger deploy on the default branch

```bash
gh workflow run <workflow-file> --ref "$DEFAULT_BRANCH"
```

**NEVER** use `--ref` with a feature branch.

### 5. Watch the deployment

```bash
sleep 3
RUN_ID=$(gh run list --workflow <workflow-file> --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID"
```

## Safety Rules

- Always deploy from the **default branch**. Never deploy a feature branch directly.
- Always verify current branch changes are merged before triggering deploy.
- Default to non-production environment. Only deploy to production on explicit user request.
- If `gh run watch` disconnects, use `gh run view <RUN_ID>` to check final status.
