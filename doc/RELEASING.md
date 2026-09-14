# Releasing to pub.dev

Releases of `ffigen_js` are published to pub.dev by GitHub Actions using
**OIDC automated publishing** — there are no long-lived secrets to manage (the
only secret is a fine-grained PAT used to create the release tag; see below).

**Releases are manual.** A push to `master` runs normal CI only; it never
releases. To cut a release, run the **Create Release** workflow by hand. With
the version left blank it reads the version from `pubspec.yaml` and tags the
`master` tip.

---

## One-time setup

Do these once before the first release.

### 1. Enable GitHub Actions publishing on pub.dev

1. Open `https://pub.dev/packages/ffigen_js/admin`
2. Under **Automated publishing**, click **Enable publishing from GitHub
   Actions**.
3. Set the repository to `nmfisher/ffigen_js` and the tag pattern to
   `v{{version}}`.

This tells pub.dev to trust OIDC tokens minted by GitHub Actions **only** when
a tag matching `v{{version}}` is pushed and the tag's version equals the
version in `pubspec.yaml`.

### 2. Create the `pub.dev` GitHub Environment

1. Repo **Settings → Environments → New environment**, name it `pub.dev`.
2. Add **Required reviewers** — the maintainers who must approve a release.

The `publish` job in `.github/workflows/publish-pub-dev.yml` targets this
environment, so nothing is published until a reviewer clicks approve.

### 3. Create the `RELEASE_TOKEN` repo secret

The `Create Release` workflow pushes the release tag. It must use a PAT, not
`GITHUB_TOKEN` — GitHub suppresses workflow triggers caused by `GITHUB_TOKEN`
pushes, so a `GITHUB_TOKEN` tag push would never fire the publish workflow.

1. GitHub → **Settings → Developer settings → Fine-grained tokens → Generate
   new token**.
2. Repository access: `nmfisher/ffigen_js` only. Permissions:
   - **Contents → Read and write**
   - **Actions → Read and write** ⚠️ — this second permission is required:
     a Contents-only PAT pushes the tag silently but **fires zero workflows**,
     so the release would never publish.
3. Add the token as a repo secret named **`RELEASE_TOKEN`**
   (Settings → Secrets and variables → Actions).

---

## Per-release flow

1. **Bump the version** in `pubspec.yaml`. Pre-release versions are fine on
   pub.dev (e.g. `0.0.16-pre`).

2. **Add a changelog entry** — prepend a `## <version>` section to
   `CHANGELOG.md`.

3. **Merge the PR to `master`.**

4. **Dispatch the release.** From the GitHub UI
   (**Actions → Create Release → Run workflow**), or from a terminal:

   ```sh
   gh workflow run "Create Release"
   ```

   Leave **version** empty — it reads the version from `master`'s
   `pubspec.yaml`. Leave **ref** at its default (`master`) so the tag lands on
   the master tip. (You can pass an explicit `version` or `ref` for a
   non-default release.)

That's it — everything below happens automatically.

### What CI does

`Create Release` (`.github/workflows/release.yml`) runs the chain on your
dispatch:

1. **`check`** — reads the version (from the input, or from `pubspec.yaml` when
   blank). If `v<version>` is already tagged **and** the release actually
   completed (the version is live on pub.dev or a successful publish run
   exists), the chain stops: nothing to do. If the tag exists but the release
   **never** completed (a *stuck tag*), the chain **fails** with instructions —
   see [Stuck tags](#stuck-tags) below.
2. **`validate`** — checks the version format, that the pubspec version matches
   the release version, and that the tag doesn't already exist.
3. **`tag`** — resolves the `master` tip, re-verifies the version, and pushes
   an annotated `v<version>` tag with the `RELEASE_TOKEN` PAT.
4. **`watch-release`** — verifies the tag push actually fired the publish
   workflow (fails within ~5 minutes if it didn't — almost always a PAT
   permission problem), then reports the publish URL, stopping early once the
   publish is waiting for your approval.

The tag push then fires the `Publish to pub.dev` workflow
(`.github/workflows/publish-pub-dev.yml`), which re-runs the gates and:

1. **`validate`** — checks the pubspec version matches the tag, confirms the
   version isn't already on pub.dev, then runs `dart pub publish --dry-run`
   (catches missing README/LICENSE, pana issues, bad file inclusion).
2. **`tests`** — the full `dart test` suite.
3. **`publish`** (behind the `pub.dev` environment approval):
   - publishes with `dart pub publish --force` (credential is the OIDC token
     provisioned by `dart-lang/setup-dart`),
   - polls pub.dev until `ffigen_js@<version>` is resolvable.

If a tag is pushed for a version that is already fully published, `validate`
short-circuits with "nothing to do", so re-running a release is safe and
idempotent.

### Stuck tags

A tag can exist without the release ever happening (e.g. the tag was pushed
while `RELEASE_TOKEN` had the wrong permissions, so no publish run fired).
The `Create Release` `check` job detects this and **fails loudly** instead of
silently skipping. To recover:

1. Fix the `RELEASE_TOKEN` PAT (add **Actions → Read and write**), **or**
2. delete the stuck tag — `git push origin :refs/tags/v<version>` — and
   re-dispatch (or bump the version instead), **or**
3. if the version is published and only the tag is missing, push the tag by
   hand: `git push origin v<version>` (it must match the pubspec version).

### Pre-flight without publishing

To check publishability without cutting a release, run the workflow manually:
**Actions → Publish to pub.dev → Run workflow**. A manual dispatch runs only
the `validate` (dry-run) job — it never publishes.

---

## Notes

- The workflow does **not** edit versions or changelogs. Bump them in the
  release PR, then merge.
- The tag pattern `v[0-9]+.[0-9]+.[0-9]+*` matches `v0.0.16`, `v0.1.0-pre`,
  etc.
