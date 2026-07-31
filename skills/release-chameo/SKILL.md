---
name: release-chameo
description: Suggest, prepare, publish, and verify a Chameo macOS release from main. Use when choosing or bumping a semantic version, updating VERSION or CHANGELOG.md, creating a release commit or tag, pushing a release, or verifying the GitHub prerelease and Sparkle appcast.
---

# Release Chameo

Use the tag-triggered GitHub Actions workflow. Treat `VERSION`, `CHANGELOG.md`,
`script/{extract_release_notes.sh,verify_release_version.sh}`, and
`.github/workflows/release.yml` as release truth.

Run bundled commands from the repository root:

```bash
skills/release-chameo/scripts/release.sh <command> [arguments]
```

## Guardrails

- Release only from a clean `main` synchronized with `origin/main`.
- Stop for unrelated changes; never stash, discard, or include them.
- Always propose `X.Y.Z` and receive explicit confirmation before editing,
  including when the user supplied a version.
- Never reuse, move, delete, retarget, or force-push a release tag.
- Push the release commit and require CI success for its exact full SHA before
  creating the annotated tag.
- Call a release published only after verifying the prerelease, ZIP, DMG,
  Markdown notes, public appcast, branch, and tag targets.

## Prepare

1. Run `release.sh inspect`. Read only the first current changelog section and
   relevant release workflow fragments if its concise output is insufficient.
2. Inspect the user-visible commits since the latest tag. Suggest patch for
   compatible fixes/refinements, minor for compatible features, or major for an
   intentional incompatibility.
3. Present the current and suggested versions, bump type, rationale, and draft
   changelog. Stop for explicit version confirmation without editing files.
4. Run `release.sh preflight X.Y.Z` after confirmation.
5. Edit only `VERSION` and `CHANGELOG.md`. Preserve prior releases and follow
   the existing headings without inventing changes.
6. Run `release.sh validate X.Y.Z`. It keeps successful test/build output terse
   and prints diagnostic log tails on failure.
7. Show the prepared version, changelog, validation summary, intended commit,
   and tag. Stop for publication confirmation. A reply such as `go ahead` to
   this prepared-release summary authorizes commit, main push, CI wait, tag
   creation/push, workflow wait, and publication verification.

## Publish

1. Commit only `VERSION` and `CHANGELOG.md` as
   `chore(release): prepare vX.Y.Z`, then push `main`.
2. Capture the full release commit SHA and run:

   ```bash
   skills/release-chameo/scripts/release.sh wait-run CI FULL_COMMIT_SHA
   ```

3. After success, run `./script/verify_release_version.sh vX.Y.Z`.
4. Create `git tag -a vX.Y.Z -m "Chameo X.Y.Z"`, prove its peeled target is
   the release commit, and push only `vX.Y.Z`.
5. Run `release.sh wait-run Release vX.Y.Z`. Investigate failures in place;
   never replace the tag.

## Verify

Run:

```bash
skills/release-chameo/scripts/release.sh verify-publication X.Y.Z FULL_COMMIT_SHA
```

Report the commit, tag, CI and Release workflow results, release URL, appcast
result/build, and manual validation boundaries. Automated checks do not prove
installed-app update/relaunch, Gatekeeper behavior, protected-resource
permission persistence, or feature-specific device/library behavior.
