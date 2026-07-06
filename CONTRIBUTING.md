# Contributing To AidFlow

AidFlow uses a small-team GitHub flow. Keep `main` releasable, work in short-lived branches, and merge through pull requests.

## Access

Collaborators should have `Write` access to the repository. Do not share personal access tokens, Apple developer credentials, signing certificates, or production secrets through GitHub issues, pull requests, commits, or screenshots.

## Branches

Use one branch per focused change:

```sh
git switch main
git pull --ff-only origin main
git switch -c feature/short-description
```

Recommended branch prefixes:

- `feature/` for new user-facing behavior.
- `fix/` for bug fixes.
- `ui/` for visual or layout-only work.
- `docs/` for documentation-only changes.
- `chore/` for maintenance.

Avoid committing directly to `main`.

## Local Verification

Before opening a pull request, run the narrowest useful verification for the change. For normal iOS work:

```sh
xcodebuild -project AidFlow.xcodeproj -scheme AidFlow -destination generic/platform=iOS -derivedDataPath /private/tmp/AidFlowDerivedData CODE_SIGNING_ALLOWED=NO build
```

For simulator UI work, also build and inspect the affected screen in Simulator when possible.

## Pull Requests

Open a draft pull request early for feedback, then mark it ready when the change is complete.

Each pull request should include:

- What changed.
- How it was tested.
- Any known limitations or follow-up work.
- Screenshots or simulator captures for UI changes.

Prefer small pull requests that can be reviewed in one pass. Split unrelated changes into separate branches.

## Review Rules

For two-person collaboration:

- The author should self-review before requesting review.
- The reviewer should focus on behavior, safety, regressions, privacy, and missed tests.
- Resolve review comments before merging.
- Use squash merge unless the branch has a carefully curated commit history.

## AidFlow-Specific Guardrails

- Keep patient identity private by default.
- Do not turn experimental tools into clinical diagnosis features.
- Keep first-aid UI low-cognitive-load and checklist-like.
- Update `README.md` when behavior, storage, privacy, build, or verification details change.
