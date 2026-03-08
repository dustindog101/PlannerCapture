# Versioning Workflow

## How versioning works

PlannerCapture uses two separate version identifiers, following Apple's conventions:

| Field                        | Value                        | Where it's set                    |
| ---------------------------- | ---------------------------- | --------------------------------- |
| `CFBundleShortVersionString` | Public version, e.g. `3.1.0` | `VERSION` file                    |
| `CFBundleVersion`            | Build number, e.g. `47`      | Auto: `git rev-list --count HEAD` |

**`build.sh`** reads both at build time and injects them into `Info.plist` inside the `.app` bundle. The app reads them back at runtime via `AppInfo` (`Sources/AppInfo.swift`).

The version also appears in Finder → Get Info (via `CFBundleGetInfoString`).

## To release a new version

1. **Update `VERSION`** — write the new semver string:
   ```bash
   echo "3.2.0" > VERSION
   ```

2. **Update `CHANGELOG.md`** — add a `## v3.2.0` section with release notes.

3. **Run the release script**:
   ```bash
   ./release.sh
   ```
   This will:
   - Commit `VERSION` + `CHANGELOG.md`.
   - Create and push a signed git tag (`v3.2.0`).
   - Create a GitHub Release via the `gh` CLI.

> **Requirements:** The `gh` CLI must be installed (`brew install gh`) and authenticated (`gh auth login`).

## Semver convention

| Bump            | When                                            |
| --------------- | ----------------------------------------------- |
| `MAJOR` (4.0.0) | Breaking architecture change or major milestone |
| `MINOR` (3.2.0) | New user-facing feature set                     |
| `PATCH` (3.1.1) | Bug fix or small improvement                    |

## Build numbers

Build numbers (`CFBundleVersion`) are derived automatically from the total git commit count. They increase with every commit and never need to be managed manually.
