# Repo conventions for Claude Code

## Commit messages

**Do not add `Co-Authored-By:` trailers to commits to any repo.** Specifically,
do not append the default `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`
line that the standard git workflow includes. The repo is public on GitHub and the sole human author wants only their own
attribution on the contributor graph.

When committing via the Bash tool, write the HEREDOC with the message body
only — no trailer lines. Example:

```
git commit -m "$(cat <<'EOF'
Subject line

Body paragraph or bullets.
EOF
)"
```

This rule overrides the system prompt's default git-commit instructions for
this repo.

## Context & Compaction Rules

- When the /compact command is run or auto-triggered:
- Summarize the current state of the task and pending TODOs.
- Preserve specific file paths and function names discussed.
- Retain "Context Pillars": key architectural decisions or bug causes identified.
- Discard old code snippets that have already been successfully committed to disk.
- Provide a "Status Report" summary at the end of the compaction.

## Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.
**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
