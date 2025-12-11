# GitS Init Roadmap (Forgejo / Gitea / GitHub)

This document tracks the roadmap for `gits init` and related repository-creation flows.

## Current behavior (Option 2)

- `gits init`
  - Prompts for platform:
    - Forgejo (default server: `forge.ourworld.tf`, customizable)
    - Gitea (default server: `git.ourworld.tf`)
    - GitHub (`github.com`)
  - Always uses `main` as the default initial branch (you can override interactively).
  - Requires that the remote repository already exists on the chosen platform.
  - Sets the remote to `https://<server>/<username>/<repo>.git` and pushes `main`.

- `gits init-list`
  - Same platform choices and server behavior as `gits init`.
  - Initializes multiple repositories in a `<username>-repos/` directory.
  - Uses `main` as the initial branch for all platforms.
  - Also assumes that each remote repository has already been created.

## Planned future behavior (Option 3)

We plan to extend `gits init` / `init-list` and potentially `gits repo create` to support **API-based repository creation** for all platforms:

- Forgejo (e.g. `forge.ourworld.tf`)
- Gitea (e.g. `git.ourworld.tf`)
- GitHub (`github.com`)

### High-level goals

- Use existing token management in `~/.config/gits/tokens.conf` to authenticate API calls.
- When a valid token is available for the selected platform/server, offer to:
  - Create the repository via the platform API.
  - Then run the local `git init`, branch creation, commit, remote add, and push.
- Support both **user** and **organization** repositories where the platform API allows it.

### Forgejo / Gitea

- Use the Gitea-style API (shared by Forgejo):
  - `POST /api/v1/user/repos` for user repositories.
  - `POST /api/v1/orgs/<org>/repos` for organization repositories.
- Respect common flags such as:
  - `private` (visibility)
  - default branch (still `main` by convention, unless the server enforces another default)
- Reuse the token lookup logic used today for `clone-all`, `fetch-issues`, and `save-issues`.

### GitHub

- Reuse the existing GitHub auth path via `gh auth` or a cached token where available.
- Use the GitHub API (or `gh repo create`) to create repositories with `main` as the initial branch.

### Non-goals (for now)

- We will **not** auto-create repositories without explicit user confirmation.
- We will **not** change existing repositories or rename default branches automatically.

---

This doc is intentionally forward-looking. When option 3 is implemented, this file should be updated to describe the final behavior and any new flags or environment variables.
