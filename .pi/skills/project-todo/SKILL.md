---
name: project-todo
description: Use this skill immediately whenever the current working directory contains a TODO.md file. Read the TODO.md, find the next incomplete task, and ask the user if they are ready to knock it out. If the directory does not contain a TODO.md, skip this skill entirely.
---

# Project TODO — Task Prompt

## Trigger condition
Use this skill **whenever** the current working directory (cwd) contains a `TODO.md` file. This applies on session start, session resume, fork, or when the user changes into a project directory mid-session.

## How to use

1. `read` the `TODO.md` file in the current directory.
2. Find the **first unchecked task** (`- [ ]`).
3. Prompt the user exactly like this:
   > "Ready to knock out **[specific task name]** now?"
4. Wait for the user's response. Do not start working until they confirm or pick a different task.

## Protocol: Auto-Commit After Repo Changes
After every chat pass where the agent makes actual edits or changes to files in a git repository:
1. Review the changed files with `git status --short`.
2. Stage the relevant changes with `git add .` unless the user explicitly requested a narrower scope.
3. Commit immediately before the final response for that chat pass.
4. Use a concise, descriptive commit message based on the completed work.
5. Do not auto-commit if no files changed, if the current directory is not inside a git repository, or if the user explicitly says not to commit.

## Protocol: Commit on Done
Whenever the user confirms a task is **done** (e.g. "that one is done", "mark it done", "check it off", etc.):
1. Update `TODO.md` — check the box (`- [ ]` → `- [x]`) and move it to the **Completed** section.
2. **Auto-commit:** Run `git add .` and `git commit -m "<task-name>"` in the project root immediately. Do not ask permission. The user said it's done; lock it in.

## Edge cases
- **No unchecked tasks:** Congratulate the user, ask if they want to add new tasks.
- **No TODO.md in cwd:** Ask the user: "I don't see a TODO.md here. Want me to create one?" Only create it if they agree.
- **User says "skip":** Move on without further prompting about todos.

## Why this exists
Keeps the user and agent aligned on the next priority without the user needing to remember to mention it.
