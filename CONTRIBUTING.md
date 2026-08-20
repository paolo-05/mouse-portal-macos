# Contributing

## Development

Open `MousePortal.xcodeproj`, select the shared `MousePortal` scheme and use the `My Mac` destination.

```sh
make xcode-build
make xcode-test
```

## Commit messages and releases

MousePortal uses Conventional Commits and semantic versioning:

- `fix: ...` produces a patch candidate.
- `feat: ...` produces a minor candidate.
- `feat!: ...` or a `BREAKING CHANGE:` footer produces a major candidate.
- `docs:`, `test:`, `refactor:`, `build:`, `ci:` and `chore:` describe changes that do not independently trigger a release.

Pushes to `main` update a Release Please pull request. Merging that pull request creates the semantic version tag, GitHub Release, changelog entry, app archive and SHA-256 checksum.
