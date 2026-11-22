# ryos-core

## Version control (jj)

Use jj, not git (the repo is colocated).

- Make one jj revision per logical change, and commit right after each change without waiting to be asked.
- When the working copy holds several unrelated changes, split them into separate revisions (`jj split -m "..." <paths>`) before doing anything else. Split by hunk when one file mixes concerns.
- Put `flake: update` (flake.lock only) first, and put fixes for the update's breakage in their own revisions after it.
- Descriptions follow the existing history: `scope: lowercase summary`, where scope is the aspect, app or area (`umbriel:`, `sunshine:`, `ai:`, `flake:`). Add a short body only when the reason isn't obvious from the summary.
