#!/usr/bin/env bash
#
# Build a release artifact for json-toolkit, and optionally publish it.
#
#   tools/release/release.sh 3.0.0             # build + gate only. No side effects
#                                              # outside target/. Safe to run anytime.
#   tools/release/release.sh 3.0.0 --publish   # the above, then sign, upload, tag, push.
#
# The same code path runs either way, so a dry run cannot drift from the real
# one. --publish adds steps at the end; it never changes what came before.
#
# Everything up to the signature is reversible and runs unprivileged. The
# signature is the boundary: dput to Launchpad is anonymous FTP, so the GPG
# signature in the .changes file is the PPA's only authentication.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO"

PACKAGE=json-toolkit
DISTRIBUTION=noble
PPA_NAME="${PPA_NAME:-ppa:code-faster/ppa}"
ARCHES="amd64 arm64"   # what Launchpad builds for this PPA
PPA_OWNER=code-faster
PPA_REPO=ppa
PPA_INDEX="https://ppa.launchpadcontent.net/${PPA_OWNER}/${PPA_REPO}/ubuntu/dists/${DISTRIBUTION}/main/binary-amd64/Packages.gz"

OUT="$REPO/target/release"
# dpkg-source shells out to Perl's File::Temp, which honours TMPDIR but is
# reached through debuild's environment scrub. Keep our own and pass it through.
export TMPDIR="${TMPDIR:-/tmp}/json-toolkit-release"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'; NC=$'\033[0m'
say()  { printf '%s\n' "$*"; }
info() { printf '%s==>%s %s\n' "$BLUE" "$NC" "$*"; }
ok()   { printf '  %sok%s   %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '  %swarn%s %s\n' "$YELLOW" "$NC" "$*"; }
die()  { printf '  %sFAIL%s %s\n' "$RED" "$NC" "$*" >&2; exit 1; }

VERSION="${1:-}"
PUBLISH=no
[ "${2:-}" = --publish ] && PUBLISH=yes
[ -n "$VERSION" ] || die "usage: $0 VERSION [--publish]"
[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must be X.Y.Z, got '$VERSION'"

mkdir -p "$TMPDIR"

# ---------------------------------------------------------------- preflight
info "Preflight"

branch=$(git branch --show-current)
[ "$branch" = master ] || die "on branch '$branch', expected master"
ok "on master"

git diff-index --quiet HEAD -- || { git status --short --untracked-files=no; die "uncommitted changes"; }
ok "working tree clean"

# The Go tools bake their version in. If that disagrees with the release
# version, --version lies to every user; catch it here rather than never.
bad=0
while IFS= read -r line; do
  file=${line%%:*}; found=$(printf '%s' "$line" | sed 's/.*= "//; s/".*//')
  [ "$found" = "$VERSION" ] || { warn "$file declares $found, releasing $VERSION"; bad=1; }
done < <(grep -rn '^const version = ' src/*.go)
[ "$bad" = 0 ] || die "version constants disagree with $VERSION"
ok "version constants all say $VERSION"

if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  warn "tag v$VERSION already exists locally"
else
  ok "tag v$VERSION is free"
fi

# The toolchain gate downloads a Go release into GOPATH, and the sumdb cache
# lives there too, so both GOCACHE and GOPATH have to be writable.
# Export unconditionally. Setting these only inside the "unwritable" branch
# left GOPATH unbound on any machine where the defaults are fine, and the
# GOMODCACHE line below then tripped set -u.
for var in GOCACHE GOPATH; do
  dir=$(go env "$var" 2>/dev/null || true)
  if [ -z "$dir" ] || ! mkdir -p "$dir" 2>/dev/null || ! [ -w "$dir" ]; then
    dir="$TMPDIR/${var,,}"
    mkdir -p "$dir"
    warn "default $var unwritable, using $dir"
  fi
  export "$var=$dir"
done
export GOMODCACHE="$GOPATH/pkg/mod"

command -v dpkg-buildpackage >/dev/null || die "dpkg-buildpackage missing (install dpkg-dev)"
command -v curl >/dev/null || die "curl missing"
ok "build tooling present"

# ------------------------------------------------------------ build + test
info "Build and test"
make clean >/dev/null
mkdir -p "$OUT"   # target/ is what make clean removes, so create OUT after it
make >"$OUT/build.log" 2>&1 || { tail -20 "$OUT/build.log"; die "build failed"; }
ok "Go binaries built"
make test >"$OUT/test.log" 2>&1 || { tail -20 "$OUT/test.log"; die "test suite failed"; }
ok "test suite passed"

dpkg-checkbuilddeps 2>"$OUT/builddeps.log" || { cat "$OUT/builddeps.log"; die "unsatisfied build-deps"; }
ok "build-deps satisfied on this machine"

# ------------------------------- gate 3: build as the buildd will build it
# The build above used whatever Go is on this machine (1.26 via the longsleep
# PPA) for amd64 only. Launchpad uses the Go that noble ships, on every arch
# in ARCHES. Both differences are invisible locally until the remote build
# fails, so reproduce them here where the feedback is seconds not minutes.
info "Gate 3: compile as the buildd will"
NOBLE_GO_PKG=$(rmadison -u ubuntu -s "$DISTRIBUTION" golang-go 2>/dev/null | awk -F'|' 'NR==1 {gsub(/ /,"",$2); print $2}')
if [ -z "$NOBLE_GO_PKG" ]; then
  die "could not ask the archive which Go $DISTRIBUTION ships.
       This gate must not pass silently; set RELEASE_SKIP_TOOLCHAIN_GATE=1 to override."
fi
GO_MM=$(printf '%s' "$NOBLE_GO_PKG" | sed 's/^[0-9]*://; s/[^0-9.].*//; s/^\([0-9]*\.[0-9]*\).*/\1/')
ok "$DISTRIBUTION ships golang-go $NOBLE_GO_PKG (Go $GO_MM)"

if [ "${RELEASE_SKIP_TOOLCHAIN_GATE:-}" = 1 ]; then
  warn "toolchain gate skipped by request"
else
  export GOTOOLCHAIN="go${GO_MM}.0"
  if ! go version >/dev/null 2>"$OUT/toolchain.log"; then
    cat "$OUT/toolchain.log"
    die "could not obtain Go $GO_MM toolchain (needs network on first run)"
  fi
  ok "using $(go version | awk '{print $3}') to match $DISTRIBUTION"
  for arch in $ARCHES; do
    for f in src/*.go; do
      GOOS=linux GOARCH="$arch" go build -o /dev/null "$f" 2>"$OUT/gate3.log" \
        || { cat "$OUT/gate3.log"; die "$(basename "$f") does not compile for $arch on Go $GO_MM"; }
    done
    ok "all Go sources compile for $arch"
  done
  unset GOTOOLCHAIN
fi

# -------------------------------------------------------- assemble sources
info "Assemble source tree"
# Two extractions of one tarball. The gate copy gets a binary build, which
# leaves debian/json-toolkit/ staging behind; the upload copy is never built
# in, so what gets signed is exactly the tarball plus debian/.
GATEDIR="$OUT/gate/$PACKAGE-$VERSION"
UPDIR="$OUT/upload/$PACKAGE-$VERSION"
ORIG="$OUT/${PACKAGE}_${VERSION}.orig.tar.gz"
mkdir -p "$OUT/gate" "$OUT/upload"

# src/json-diff is a gitignored leftover from an old in-tree build. It would
# otherwise be swept into the tarball as a stale, arch-specific binary.
tar czf "$ORIG" \
  --exclude=src/json-diff \
  --transform "s#^#$PACKAGE-$VERSION/#" \
  Makefile src go.mod go.sum vendor README.md LICENSE
CHANGELOG_STAMP=$(date -R)
for d in "$OUT/gate" "$OUT/upload"; do
  cp "$ORIG" "$d/"
  tar xf "$ORIG" -C "$d"
  cp -r debian "$d/$PACKAGE-$VERSION/debian"
  printf '%s (%s) %s; urgency=medium\n\n  * Release %s\n\n -- %s <%s>  %s\n' \
    "$PACKAGE" "$VERSION" "$DISTRIBUTION" "$VERSION" \
    "$(git config user.name)" "$(git config user.email)" "$CHANGELOG_STAMP" \
    > "$d/$PACKAGE-$VERSION/debian/changelog"
done
ok "two source trees assembled, changelog targets $DISTRIBUTION"

# ------------------------------------------- binary build, for the gates only
# This .deb is never uploaded. Launchpad rebuilds from source for each arch.
# It exists so the gates below can assert on a real package payload, which is
# the check that catches a package that installs cleanly and does the wrong
# thing -- something no clean-room build test looks at.
info "Build a binary package to inspect"
( cd "$GATEDIR" && dpkg-buildpackage -us -uc -b -d ) >"$OUT/binbuild.log" 2>&1 \
  || { tail -25 "$OUT/binbuild.log"; die "binary package build failed"; }
DEB=$(ls -1t "$OUT/gate/${PACKAGE}_${VERSION}_"*.deb 2>/dev/null | head -1)
[ -n "$DEB" ] || die "no .deb produced"
ok "built $(basename "$DEB")"

dpkg-deb -c "$DEB" | awk '{print $NF}' | grep '/usr/bin/' | grep -v '/$' \
  | sed 's#^\./usr/bin/##' | sort > "$OUT/payload.new"
NEW_COUNT=$(wc -l < "$OUT/payload.new")
ok "$NEW_COUNT executables in the payload"

# ------------------------------------------------------- gate 1: no dropped tools
# 2.0.6 would have shipped without json-to-logfmt and logfmt-to-json, because
# the packaging installed a different Makefile's program list. apt would have
# upgraded users straight into losing both. This is that gate.
info "Gate 1: payload regression"
if curl -sSf -o "$OUT/Packages.gz" "$PPA_INDEX" 2>/dev/null; then
  PUBLISHED=$(zcat "$OUT/Packages.gz" \
    | awk -v p="$PACKAGE" '$1=="Package:" {inpkg = ($2==p)} inpkg && $1=="Version:" {print $2}' \
    | sort -V | tail -1)
else
  PUBLISHED=""
fi

if [ -z "$PUBLISHED" ]; then
  warn "no published version found in the PPA; nothing to compare against"
  : > "$OUT/payload.old"
else
  FILENAME=$(zcat "$OUT/Packages.gz" | awk -v p="$PACKAGE" -v v="$PUBLISHED" '
    $1=="Package:" {inpkg = ($2==p); ver=""} inpkg && $1=="Version:" {ver=$2}
    inpkg && $1=="Filename:" && ver==v {print $2; exit}')
  curl -sSf -o "$OUT/published.deb" \
    "https://ppa.launchpadcontent.net/${PPA_OWNER}/${PPA_REPO}/ubuntu/${FILENAME}" \
    || die "could not download published $PUBLISHED for comparison"
  dpkg-deb -c "$OUT/published.deb" | awk '{print $NF}' | grep '/usr/bin/' | grep -v '/$' \
    | sed 's#^\./usr/bin/##' | sort > "$OUT/payload.old"
  ok "comparing against published $PUBLISHED ($(wc -l < "$OUT/payload.old") executables)"
fi

DROPPED=$(comm -23 "$OUT/payload.old" "$OUT/payload.new" || true)
ADDED=$(comm -13 "$OUT/payload.old" "$OUT/payload.new" || true)
[ -n "$ADDED" ] && say "  added:   $(echo "$ADDED" | tr '\n' ' ')"
if [ -n "$DROPPED" ]; then
  for tool in $DROPPED; do
    # An intentional removal has to be stated in the changelog body, where it
    # ends up in front of a human. Silence is treated as an accident.
    # grep -c reads all input, so no SIGPIPE; || true absorbs its exit 1 on zero.
    if [ "$(git log -1 --format=%B | grep -c "removes $tool" || true)" != 0 ]; then
      warn "$tool dropped, declared in the commit message"
    else
      say "  ${RED}dropped:${NC} $tool"
      die "$tool is in published $PUBLISHED but not in $VERSION.
       If that is deliberate, say 'removes $tool' in the release commit message."
    fi
  done
else
  ok "no executable disappeared"
fi

# ------------------------------------------------ gate 2: every Depends exists
# 2.0.5 shipped a hard dependency on python3-logfmt, a package that has never
# existed in any Debian or Ubuntu suite. Launchpad built it happily -- a bogus
# runtime dep only bites at install time -- and the package sat uninstallable
# in the PPA for ten months. One apt-cache lookup would have caught it.
info "Gate 2: dependency resolvability"
DEPENDS=$(dpkg-deb -f "$DEB" Depends)
say "  $DEPENDS"
missing=""
allnames=""
# Split on commas; take the first alternative; drop version constraints and
# arch qualifiers. python3:any is an arch-qualified real package, not a typo.
while IFS= read -r dep; do
  name=$(printf '%s' "$dep" | sed 's/|.*//; s/(.*)//; s/:[a-z0-9]*$//' | tr -d ' ')
  [ -n "$name" ] || continue
  allnames="$allnames $name"
  # Capture first, then match. `apt-cache ... | grep -q` looks right but is a
  # trap: grep -q exits at the first match, apt-cache takes SIGPIPE, and under
  # `set -o pipefail` the pipeline reports 141. Every lookup then "fails".
  policy=$(apt-cache policy "$name" 2>/dev/null || true)
  cand=$(printf '%s\n' "$policy" | awk '/Candidate:/ {c=$2} END {print c}')
  if [ -n "$cand" ] && [ "$cand" != "(none)" ]; then
    continue
  fi
  # A purely virtual package is fine as long as something provides it.
  showpkg=$(apt-cache showpkg "$name" 2>/dev/null || true)
  providers=$(printf '%s\n' "$showpkg" | awk '/^Reverse Provides:/ {f=1; next} f && NF {print}')
  if [ -n "$providers" ]; then
    continue
  fi
  missing="$missing $name"
  # printf '%s\n', not '%s': without the trailing newline `read` discards the
  # final field, and the last dependency would never be checked.
done < <(printf '%s\n' "$DEPENDS" | tr ',' '\n')

if [ -n "$missing" ]; then
  for m in $missing; do say "  ${RED}unresolvable:${NC} $m"; done
  die "dependencies that no configured suite can satisfy:$missing"
fi
ok "every dependency resolves on this machine"

# This machine carries the longsleep Go PPA, Mint's repos and several others,
# so "resolves here" is weaker than "resolves in noble". Ask the archive.
# A dependency satisfiable only from a PPA installs fine locally and leaves
# every other noble user with an uninstallable package -- which is exactly
# how python3-logfmt survived review.
uniq_names=$(printf '%s\n' $allnames | sort -u | tr '\n' ' ')
mad=$(rmadison -u ubuntu -s "$DISTRIBUTION,$DISTRIBUTION-updates,$DISTRIBUTION-security" $uniq_names 2>/dev/null || true)
if [ -z "$mad" ]; then
  die "could not reach the archive to confirm $DISTRIBUTION has these packages.
       This gate must not pass silently; set RELEASE_SKIP_ARCHIVE_GATE=1 to override."
fi
notinsuite=""
archgap=""
for n in $uniq_names; do
  # Trim into a scratch variable, never into $1: assigning to a field makes
  # awk rebuild $0 with OFS, which would strip the | separators we still need.
  rows=$(printf '%s\n' "$mad" | awk -F'|' -v n="$n" '{k=$1; gsub(/ /,"",k)} k==n {print}')
  if [ -z "$rows" ]; then notinsuite="$notinsuite $n"; continue; fi
  arches=$(printf '%s\n' "$rows" | awk -F'|' '{print $4}' | tr ',' ' ')
  for a in $ARCHES; do
    case " $arches " in
      *" $a "*) ;;
      *) case " $arches " in *" all "*) ;; *) archgap="$archgap $n/$a" ;; esac ;;
    esac
  done
done
if [ -n "$notinsuite" ]; then
  for n in $notinsuite; do say "  ${RED}not in $DISTRIBUTION:${NC} $n"; done
  die "dependencies missing from $DISTRIBUTION:$notinsuite"
fi
[ -n "$archgap" ] && die "dependencies missing on some build arch:$archgap"
ok "every dependency exists in $DISTRIBUTION for $ARCHES"

# -------------------------------------------------------- source package
info "Build the source package"
CHANGES="$OUT/upload/${PACKAGE}_${VERSION}_source.changes"
# Unsigned on purpose. Signing is the one act that stays with Tyler, and it is
# also the PPA's only authentication, so an unsigned artifact is inert: it
# cannot be uploaded by anyone who finds it.
( cd "$UPDIR" && dpkg-buildpackage -S -sa -d -nc -us -uc ) >"$OUT/srcbuild.log" 2>&1 \
  || { tail -25 "$OUT/srcbuild.log"; die "source package build failed"; }
[ -f "$CHANGES" ] || die "expected $CHANGES"
ok "built $(basename "$CHANGES") (unsigned)"

# ---------------------------------------------------------------- manifest
say ""
printf '%s========================================%s\n' "$BLUE" "$NC"
printf '%s  %s %s -> %s%s\n' "$BLUE" "$PACKAGE" "$VERSION" "$PPA_NAME" "$NC"
printf '%s========================================%s\n' "$BLUE" "$NC"
say "  distribution   $DISTRIBUTION"
say "  published now  ${PUBLISHED:-none}"
say "  executables    $NEW_COUNT"
[ -n "$ADDED" ]   && say "  added          $(echo "$ADDED" | tr '\n' ' ')"
[ -n "$DROPPED" ] && say "  dropped        $(echo "$DROPPED" | tr '\n' ' ')"
say "  depends        $DEPENDS"
say "  artifact       $CHANGES"
say ""

if [ "$PUBLISH" != yes ]; then
  say "Artifact built and gated. Nothing was signed, uploaded or pushed."
  say "To publish:  make deploy VERSION=$VERSION"
  exit 0
fi

# ----------------------------------------------------------------- publish
info "Publish"
say "GPG will now ask for your passphrase. That is the authorisation:"
say "cancel it and nothing is uploaded."
say ""

if [ -n "${DEBSIGN_KEY:-}" ]; then
  debsign -k "$DEBSIGN_KEY" "$CHANGES"
else
  debsign "$CHANGES"   # keyed off the maintainer address in the changelog
fi
ok "signed"

dput "$PPA_NAME" "$CHANGES"
ok "uploaded to $PPA_NAME (irreversible: Launchpad never deletes a version)"

# Tag and push only after the upload succeeds, so a tag never claims a release
# that does not exist in the PPA.
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  ok "tag v$VERSION already exists"
else
  git tag -a "v$VERSION" -m "Release $VERSION"
  ok "tagged v$VERSION"
fi
git push origin "$(git branch --show-current)"
git push origin "v$VERSION"
ok "pushed commits and tag"

say ""
say "Done. Launchpad publishes 10-30 minutes after upload."
say "Watch it:   ./check-ppa-build.sh $PACKAGE $VERSION"
