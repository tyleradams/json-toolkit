# Release Process

This document describes the release process for JSON Toolkit using the automated `release.sh` script.

## Quick Start

For a full release with all validation and publishing:

```bash
export DEBSIGN_KEY=YOUR_GPG_KEY_ID
./release.sh 1.2.3
```

**Note**: All output is automatically logged to `logs/release-YYYYMMDD-HHMMSS.log` with timestamps to prevent collisions. No need to manually pipe to `tee`.

## Prerequisites

1. **Docker** - Required for clean environment testing
2. **Git** - For version control and tagging
3. **debuild, debsign, dput** - For Debian packaging (install `devscripts`)
4. **GPG Key** - For signing packages (set `DEBSIGN_KEY` environment variable)

## Release Pipeline Phases

The release script executes six phases:

### Phase 1: Local Build and Test
- Cleans previous builds
- Compiles all Go programs
- Runs full test suite locally
- **Purpose**: Quick sanity check before expensive Docker operations

### Phase 2: Docker Package Build
- Builds Ubuntu 22.04 Docker image with all dependencies
- Compiles project in clean environment
- Extracts built artifacts
- **Purpose**: Ensure build works in clean environment

### Phase 3: Docker Install and Test
- Creates fresh Ubuntu 22.04 container
- Installs json-toolkit from source
- Runs complete test suite
- Performs smoke tests on key utilities
- **Purpose**: Verify installation and functionality in production-like environment

### Phase 4: Git Publishing
- Commits any outstanding changes (with confirmation)
- Creates version tag (e.g., `v1.2.3`)
- Pushes commits and tags to origin
- **Purpose**: Version control and GitHub release

### Phase 5: PPA Publishing
- Builds Debian source package
- Signs package with GPG key
- Uploads to PPA via dput
- **Purpose**: Make package available via apt

### Phase 6: PPA Verification
- Waits for PPA processing (2 minutes)
- Creates Docker container that installs from PPA
- Verifies installation and runs smoke tests
- **Purpose**: Ensure published package works correctly

## Usage Examples

### Full Release
```bash
# Set your GPG key for signing
export DEBSIGN_KEY=ABCD1234

# Run complete release pipeline
./release.sh 1.2.3
```

### Testing Before Release

#### Local testing only (fastest)
```bash
./release.sh --local-only 1.2.3
```

#### Docker testing only (no publishing)
```bash
./release.sh --docker-only 1.2.3
```

#### Everything except PPA
```bash
./release.sh --skip-ppa 1.2.3
```

### Skip Specific Phases
```bash
# Skip Docker build (if already validated)
./release.sh --skip-phase 2 1.2.3

# Skip multiple phases
./release.sh --skip-phase 2 --skip-phase 3 1.2.3
```

## Environment Variables

- **DEBSIGN_KEY** (required for PPA): Your GPG key ID for signing packages
- **PPA_NAME** (optional): Override default PPA (default: `ppa:code-faster/ppa`)
- **DEBFULLNAME** (optional): Full name for debian/changelog
- **DEBEMAIL** (optional): Email for debian/changelog

Example:
```bash
export DEBSIGN_KEY=0x1234ABCD
export DEBFULLNAME="Tyler Adams"
export DEBEMAIL="tyler@example.com"
export PPA_NAME="ppa:myteam/json-toolkit"
./release.sh 1.2.3
```

## Troubleshooting

### PPA Verification Fails

If Phase 6 fails, the package may not be processed yet. PPA processing can take 5-30 minutes. Try:

1. Wait 10-15 minutes
2. Manually verify: `docker build -f <dockerfile> -t json-toolkit-verify .`
3. Check PPA status: https://launchpad.net/~code-faster/+archive/ubuntu/ppa

### Docker Errors

If Docker phases fail:

1. Ensure Docker daemon is running: `sudo systemctl start docker`
2. Check Docker permissions: `sudo usermod -aG docker $USER` (then logout/login)
3. Clean Docker images: `docker system prune -a`

### Git Push Fails

If you don't have push access or tag already exists:

1. Check remote: `git remote -v`
2. Delete local tag: `git tag -d v1.2.3`
3. Delete remote tag: `git push origin :refs/tags/v1.2.3`

### GPG Signing Fails

If package signing fails:

1. List keys: `gpg --list-secret-keys --keyid-format LONG`
2. Export key: `export DEBSIGN_KEY=YOUR_KEY_ID`
3. Test signing: `debsign -k $DEBSIGN_KEY <package>.changes`

## Manual Release Steps

If the automated script fails, you can run steps manually:

```bash
# 1. Local build and test
make clean && make && make test

# 2. Update version
vim Makefile  # Update VERSION
dch -v 1.2.3 -D focal "Release version 1.2.3"

# 3. Git operations
git add -A
git commit -m "Release version 1.2.3"
git tag -a v1.2.3 -m "Release version 1.2.3"
git push origin master
git push origin v1.2.3

# 4. Build and publish package
make package
make publish DEBSIGN_KEY=YOUR_KEY_ID

# 5. Wait and verify
# Wait 15-30 minutes, then test:
docker run -it ubuntu:22.04
apt update
apt install software-properties-common
add-apt-repository ppa:code-faster/ppa
apt update
apt install json-toolkit
json-diff --help
```

## Post-Release Checklist

After successful release:

- [ ] Verify GitHub tag created: https://github.com/tyleradams/json-toolkit/tags
- [ ] Check PPA build status: https://launchpad.net/~code-faster/+archive/ubuntu/ppa
- [ ] Test installation on fresh Ubuntu VM/container
- [ ] Update any documentation with new version number
- [ ] Announce release (if applicable)

## Versioning

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (e.g., 1.2.3)
- **MAJOR**: Breaking changes
- **MINOR**: New features, backwards compatible
- **PATCH**: Bug fixes, backwards compatible

## Release Frequency

- **Patch releases**: As needed for bug fixes
- **Minor releases**: Monthly or when new features are ready
- **Major releases**: When breaking changes are necessary

## Rollback

If a release has issues:

1. **Git**: Create hotfix from previous tag
2. **PPA**: Upload new version (Launchpad doesn't allow deletions)
3. **Users**: Can pin to previous version: `apt install json-toolkit=1.2.2`
