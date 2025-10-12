# Versioning Strategy

json-toolkit uses a **tag-driven versioning approach**, following best practices from sophisticated projects like the Linux kernel and Go modules.

## Philosophy

- **Git tags are the sole source of truth** for releases
- **No special "Release" commits** - commits are for code changes only
- **Version numbers live in git tags**, not in committed files (except CHANGELOG.md for documentation)

## How It Works

### Version Discovery

The Makefile automatically derives the version from git tags:

```makefile
VERSION ?= $(shell git describe --tags --always --dirty | sed 's/^v//' || echo "dev")
```

**Examples:**
- On tag `v2.0.0`: `VERSION=2.0.0`
- After tag: `VERSION=2.0.0-1-gabcd123` (1 commit past v2.0.0)
- With uncommitted changes: `VERSION=2.0.0-dirty`
- No tags yet: `VERSION=dev`

### Debian Changelog

`debian/changelog` is **NOT checked into git**. It's generated at package-build time from git history using either:
1. `gbp dch` (git-buildpackage) - preferred
2. Fallback: Simple generation from git user/date

This keeps the repo clean and avoids merge conflicts.

## Release Process

### 1. Normal Development
Make commits as usual. No version numbers needed:
```bash
git commit -m "Add new feature"
git commit -m "Fix bug in csv-to-json"
```

### 2. Prepare for Release
Update CHANGELOG.md (optional, for human documentation):
```bash
# Edit CHANGELOG.md: Change ## [2.0.0] - TBD to actual date
```

### 3. Tag the Release
```bash
# Commit CHANGELOG if modified
git commit -am "Update CHANGELOG for v2.0.0"

# Create annotated, signed tag
git tag -s -a v2.0.0 -m "Release 2.0.0"

# Push
git push origin master v2.0.0
```

### 4. Automated Release (using release.sh)
```bash
./release.sh 2.0.0
```

This automatically:
- Updates CHANGELOG.md date (TBD → actual date)
- Runs all tests (local + Docker)
- Commits CHANGELOG
- Creates signed tag `v2.0.0`
- Generates `debian/changelog` from git
- Builds & publishes to PPA

## Comparison to Other Approaches

### "Normie" Approach (Common but not ideal)
```bash
# Update version in Makefile
sed -i 's/VERSION = 1.0/VERSION = 2.0/' Makefile
git commit -m "Release version 2.0.0"  # ← Special release commit
git tag v2.0.0
```

**Problems:**
- Empty "Release" commit wastes history
- Version in file can drift from tags
- Merge conflicts on version file

### Sophisticated Approach (Linux, Go, json-toolkit)
```bash
# No version files to update!
git commit -m "Fix bug"  # ← Normal commit
git tag -s v2.0.0        # ← Tag marks the release
```

**Benefits:**
- Tags are canonical
- No version drift
- Clean history
- Version auto-computed from VCS

## For Contributors

### To check current version:
```bash
make help  # Shows VERSION=$(VERSION)
git describe --tags
```

### To test without tags:
```bash
# Will show VERSION=dev
make clean && make
```

### After cloning:
```bash
# Fetch tags
git fetch --tags

# Now version works
make
```

## Technical Details

### git describe format:
```
v2.0.0-3-gabcd123-dirty
│      │ │        └── uncommitted changes
│      │ └────────── short commit hash
│      └──────────── commits since tag
└─────────────────── nearest tag
```

### Debian packaging:
The `make package` target:
1. Runs `gbp dch --new-version=$(VERSION)` to generate `debian/changelog`
2. Falls back to simple generation if `gbp` not available
3. Packages with the derived version

### Why not check in debian/changelog?
- Avoids merge conflicts (changelog always at top of file)
- Git history is the source of truth
- Automatically includes all commits
- Cleaner repo

## References

- Linux kernel: Uses tags + version in Makefile (small bump commit then tag)
- Go modules: Tags only, version injected at build time
- git-buildpackage: Debian packaging from git, generates changelogs
- Semantic Versioning: https://semver.org/
