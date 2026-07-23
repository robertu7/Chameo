---
name: release-chameo
description: Suggest, prepare, and publish a new Chameo macOS app version from the main branch, with user confirmation before release edits. Use when asked to choose or bump Chameo's semantic version, update its changelog, create a release commit and tag, push the release to GitHub, or verify the tagged GitHub prerelease and Sparkle appcast.
---

# Release Chameo

Publish releases through the repository's existing tag-triggered GitHub Actions
workflow. Treat `VERSION`, `CHANGELOG.md`, and `.github/workflows/release.yml` as
the sources of truth.

## Guardrails

- Work only from `main`, with `HEAD` synchronized to `origin/main`.
- Stop if unrelated tracked or untracked changes are present. Do not include,
  stash, discard, or overwrite them without the user's direction.
- Always propose an `X.Y.Z` semantic version and obtain the user's explicit
  confirmation before mutating files, even when the user supplied a version.
- Never create or move a release tag before its release commit is on
  `origin/main` and the corresponding CI run succeeds.
- Never reuse, force-push, delete, or retarget a tag that exists locally or on
  GitHub. Investigate a failed release workflow in place.
- Do not claim the release is published until the GitHub prerelease, its two
  assets, and the public Sparkle appcast are verified.

## Prepare the release

1. Read `VERSION`, the first section of `CHANGELOG.md`, recent commits since the
   latest `vX.Y.Z` tag, and `.github/workflows/{ci,release}.yml`.
2. Fetch `origin` and inspect the commits and user-visible changes since the
   latest release. Suggest the next version using Semantic Versioning:
   - increment patch for backward-compatible fixes or small refinements;
   - increment minor for backward-compatible user-visible functionality;
   - increment major for an intentional incompatible change.
3. Present the suggested version, the current version, the bump type, a concise
   rationale grounded in the actual changes, and a draft changelog summary. Ask
   the user to confirm or choose another version. Stop and wait for an explicit
   answer; do not edit `VERSION` or `CHANGELOG.md`, commit, tag, or push yet.
4. After confirmation, confirm:
   - the current branch is `main`;
   - `HEAD` equals `origin/main`;
   - the worktree is clean;
   - neither local nor remote tag for the confirmed version exists.
5. Update `VERSION` to the confirmed version.
6. Add the newest `CHANGELOG.md` section for the confirmed version, following the existing
   headings and describing user-visible changes accurately. Do not invent
   changes or remove prior releases.
7. Validate the release inputs:

   ```bash
   ./script/extract_release_notes.sh X.Y.Z /tmp/chameo-X.Y.Z-release-notes.md
   git diff --check
   swift test
   swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warn-concurrency
   ```

8. Show the version, changelog, validation results, and intended release commit
   and tag. Obtain confirmation before the externally visible commit, push, and
   tag operations unless the user's invocation already explicitly authorized
   all of them after confirming the version.

## Publish

1. Commit only `VERSION` and `CHANGELOG.md` with:

   ```text
   chore(release): prepare vX.Y.Z
   ```

2. Push `main` to `origin`.
3. Wait for the GitHub Actions `CI` run for that exact commit to succeed. Stop
   before tagging if it fails or cannot be matched to the commit.
4. Run `./script/verify_release_version.sh vX.Y.Z`.
5. Create an annotated tag:

   ```bash
   git tag -a vX.Y.Z -m "Chameo X.Y.Z"
   ```

6. Confirm the tag targets the release commit, then push only that tag:

   ```bash
   git push origin vX.Y.Z
   ```

The tag push triggers `.github/workflows/release.yml`. That workflow builds the
app, publishes a GitHub prerelease with the archive and Markdown release notes,
and deploys the signed Sparkle appcast to GitHub Pages.

## Verify publication

Wait for the `Release` workflow for `vX.Y.Z` to succeed, then verify:

- the GitHub release is a prerelease titled `Chameo X.Y.Z`;
- `Chameo-X.Y.Z-arm64.zip` and `Chameo-X.Y.Z-arm64.md` both exist;
- `https://robertu7.github.io/Chameo/appcast.xml` contains `X.Y.Z`;
- the local branch is clean and matches `origin/main`;
- local and remote `vX.Y.Z` resolve to the release commit.

Report the commit SHA, tag, workflow result, release URL, and appcast result.
State any verification boundary or failure precisely.
