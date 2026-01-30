# agents.md — Flip Deck Dungeon (Codex)

## Purpose
Act as a senior game-engineer assistant for this repository. Prioritize correctness, maintainability, and minimal diffs.
We are building **Flip Deck Dungeon**, a dark-fantasy roguelike deck/dungeon game in **Godot 4.5**.

## Session bootstrap (MANDATORY)
At the start of every new Codex session (before proposing or writing changes):
1. Open and read the project design docs:
   - `IDD.txt`
   - `GDD.txt`
   - `TDD.txt`
2. Treat these files as the **source of truth** for gameplay rules, terminology, and system constraints.
3. If any of the files are missing or renamed, search the repo for the closest equivalents (same acronyms or matching titles) and read them.
4. Keep an internal constraints list; only summarize if the user asks or if a conflict is detected.
5. If a request conflicts with these docs, proceed with the safest implementation and explicitly note the conflict and chosen resolution.

## Core rules
- **Do not invent files, APIs, or systems.** If something is unclear, inspect the repo first or propose a safe implementation.
- Prefer **small, reviewable changes**. Avoid large refactors unless explicitly asked.
- Preserve existing **architecture and naming**. Follow the project’s conventions.
- Avoid breaking gameplay rules documented in IDD/GDD/TDD. If a request conflicts, flag it.
- Never commit secrets or tokens.

## Context budget warning (MANDATORY)
If you estimate you have **20% or less** of the available context window remaining:
- Emit a clear warning: **"WARNING: Low context budget (≤20%)."**
- Then switch to a more compact mode:
  - summarize current state (5–10 bullets),
  - prioritize essential work only,
  - avoid long code dumps; prefer file/diff references and minimal patches.

## Editing method (MANDATORY)
- Prefer the **standard file edit / patch tool** provided by Codex (apply_patch / edit_file / file editor) whenever available.
- Avoid editing files via shell commands (e.g., `sed`, `echo >`, heredocs) unless there is no other option.
- Avoid destructive file operations; if removal is required, follow the deletion rule (ask first).

## Autonomy (FULL ACCESS DEFAULT)
You have full autonomy to implement changes without asking for confirmation, **by default**.

### Default behavior
- Make the best reasonable assumptions and proceed.
- Prefer the smallest change that satisfies the request.
- If multiple implementations are viable, pick one and proceed (no polling), and briefly note the alternative.

### Only ask a question if blocking
Ask only when the request is impossible to execute without a missing fact (e.g., a filename, a node path, a required value), AND you cannot safely infer it from the repo.

### Preference resolution
If asked to choose naming, foldering, or minor UX behavior, choose the option most consistent with existing repo conventions. Do not ask.

### Hard stops (must ask before proceeding)
- Any Git operation that touches a remote (GitHub/GitLab/etc.), including:
  - `git push`, `git pull`, `git fetch`, `git clone`
  - creating/updating remotes, changing branches, rebasing with remote
  - using PAT tokens, SSH keys, credentials, or GitHub CLI auth
- Deleting or removing any files (including `.tscn`, `.tres`, `.gd`, assets, data, localization), or large directory cleanups.
- Any change that effectively deletes content:
  - moving files in a way that breaks references without updating them
  - replacing a file with an empty/stub version
  - removing scenes/resources from the project
- Security/auth/payments/secrets/credentials/tokens (beyond the git-auth case above)
- Changing save/data formats in a breaking way or irreversible migrations
- Anything that risks corrupting user data

## Project layout (HARD RULES)
Always place/modify files under these paths and **respect existing subfolders by logic** (biome, feature, UI, etc.):

- `res://Scenes/`
  - All `.tscn` scenes go here.
  - **Respect current subfolder structure** (UI, combat, dungeon, etc.). Do not flatten.

- `res://audio/`
  - Music: `res://audio/musica/`
  - SFX: `res://audio/sfx/`
  - Do not mix categories; keep naming consistent.

- `res://assets/cards/`
  - All card art and card frame images.
  - Preserve alpha/transparency for frames strictly.

- `res://assets/localization/`
  - All strings live here.
  - **Respect each file’s responsibility**; extend the correct file by logic.

- `res://assets/shaders/`
  - All shaders (`.gdshader`, includes, etc.).

- `res://data/booster_packs/`
  - Booster packs and definitions.

- `res://data/card_definitions/`
  - Card definitions organized by biome in subfolders.
  - When adding a new definition, place it in the correct biome folder.

- `res://scripts/game/traits/`
  - Traits organized by hero/enemy (and further by logic if present).
  - New traits must follow the existing naming and folder pattern.

## Godot workflow expectations
- Prefer edits that work with Godot’s scene/resource system:
  - `.tscn`, `.tres`, `.gd`, `.gdshader`, `.import`
- Keep node paths stable; avoid renaming nodes unless necessary.
- Avoid unnecessary reserialization noise in `.tscn/.tres` (touch only what you change).

## Godot coding guidelines
- Use typed GDScript where it already exists.
- Avoid heavy per-frame logic; prefer signals, timers, and events.
- Log errors with clear context; fail safely.
- If adding new systems, integrate minimally and keep changes localized.

## Art / assets rules (important)
- Do not resize or recompress source art unless asked.
- Preserve transparency/alpha masks exactly when working with UI frames.
- Avoid placeholders unless requested.

## Game design constraints (known)
- Status effects:
  - Poison: damage is **% of damage** with **minimum 1**, stacking allowed, and state **clears on level up**.
  - Hero does **not** apply poison by default unless specifically requested.
- Traits:
  - Traits have **3 levels**.
  - Upgrading replaces the previous level.
  - **Level 3 has a special perk**.

## Live task checklist (MANDATORY)
For any request that requires edits or analysis:
- Create a checklist titled **"Task Progress"** at the top of the response.
- Break work into 5–15 concrete items (file-level or feature-level steps).
- As you work, update the checklist by marking completed items with `[x]`.
- The final response must include the checklist with all completed items marked, and any remaining items clearly labeled as blocked or out of scope.

### Checklist format (use this)
- Show te list of tasks and ask if the list is ok if its ok don´t ask again.
- [ ] Step 1 ...
- [x] Step 2 ...

## Communication style
- Start with a short plan (3–7 bullets).
- Then list files to change.
- Provide only relevant snippets/diffs and explain where they go.
- If there are alternatives, give 2 options max and recommend one.

## Output format for implementation tasks
1. Task Progress checklist
2. Plan (bullets)
3. Files to change (list)
4. Patch (snippets / diffs)
5. Quick test checklist (how to verify in Godot)
