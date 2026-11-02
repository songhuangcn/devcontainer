---
name: create-skill
description: 'Create skills following the standard format and directory conventions. Use when user asks to "create a skill", "创建 skill", "记录成 skill", "保存为 skill", or similar. Ensures correct directory, frontmatter format, and content structure by referencing existing skills.'
license: MIT
allowed-tools: Bash, Read, Write, Glob, Grep
---

# Create Skill

## Overview

Create well-structured skills following the established conventions. Skills are Markdown files with YAML frontmatter that provide domain-specific instructions and workflows. They are tool-agnostic and can be used by any AI coding agent (OpenCode, Claude Code, Cursor, etc.).

## Scope Rules

| User intent | Keywords | Location |
|---|---|---|
| **Default (no scope specified)** | "创建 skill", "create skill" | `~/.agents/skills/<name>/SKILL.md` (global) |
| **Project-level** | "项目级 skill", "project skill", "local skill" | `<project-root>/.agents/skills/<name>/SKILL.md` |

**Always default to global scope** unless the user explicitly requests project-level.

## Workflow

### 1. Reference existing skills for format conventions

Before writing, read 1-2 existing skills to match the current format:

```bash
ls ~/.agents/skills/
```

Pick a representative skill and read its frontmatter + structure:

```bash
head -30 ~/.agents/skills/git-commit/SKILL.md
```

### 2. Determine skill metadata

From the user's request, derive:

- **name**: lowercase, hyphen-separated (e.g. `deploy`, `create-skill`, `code-review`)
- **description**: single-line, concise, includes trigger phrases. Wrapped in single quotes in frontmatter.
- **allowed-tools**: only the tools the skill actually needs (e.g. `Bash`, `Read`, `Write`, `Glob`, `Grep`)

### 3. Create the skill file

Directory structure:

```
~/.agents/skills/<name>/SKILL.md              # global (default)
<project-root>/.agents/skills/<name>/SKILL.md  # project-level (only when explicitly requested)
```

### 4. SKILL.md format

```markdown
---
name: <skill-name>
description: '<one-line description with trigger phrases>'
license: MIT
allowed-tools: <comma-separated tool list>
---

# <Skill Title>

## Overview

<1-2 sentences explaining what this skill does.>

## Workflow

### 1. <First step>

<Instructions with code blocks where appropriate.>

### 2. <Next step>

...

## <Additional sections as needed>

<Rules, safety notes, best practices, etc.>
```

## Format Rules

- **Frontmatter** is required: `name`, `description` are mandatory; `license` and `allowed-tools` are recommended.
- **description** must be wrapped in **single quotes** (it often contains colons, parentheses, etc.).
- **Content** should be actionable — include concrete commands, decision trees, and examples.
- **Keep it focused** — one skill per concern. Don't bundle unrelated workflows.
- **Use tables** for decision matrices (e.g. environment selection, scope rules).
- **Include trigger phrases** in the description so the agent knows when to load the skill (both English and Chinese if applicable).
