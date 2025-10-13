#!/usr/bin/env bash
set -euo pipefail

# Check Launchpad PPA build status with detailed diagnostics

PACKAGE="${1:-json-toolkit}"
VERSION="${2:-}"
PPA_NAME="${PPA_NAME:-ppa:code-faster/ppa}"

# Extract PPA owner and name
PPA_OWNER=$(echo "$PPA_NAME" | sed 's/ppa:\([^/]*\).*/\1/')
PPA_REPO=$(echo "$PPA_NAME" | sed 's/ppa:[^/]*\/\(.*\)/\1/')

PPA_URL="https://launchpad.net/~${PPA_OWNER}/+archive/ubuntu/${PPA_REPO}"
BUILDERS_URL="https://launchpad.net/builders/"

echo "===== PPA Build Diagnostics ====="
echo "Package: $PACKAGE"
echo "Version: ${VERSION:-latest}"
echo "PPA: $PPA_NAME"
echo ""

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "ERROR: curl is required but not installed"
    exit 1
fi

echo "===== 1. Builder Queue Status ====="
echo "Fetching: $BUILDERS_URL"
echo ""

BUILDERS_PAGE=$(curl -sL "$BUILDERS_URL")

# Extract queue information
echo "Current Build Farm Status:"
echo "$BUILDERS_PAGE" | grep -A 5 "available build machine" | head -10 || echo "Could not parse builder status"
echo ""

# Check for specific architecture queues
echo "Architecture Queue Status:"
for ARCH in amd64 arm64 armhf i386 ppc64el s390x; do
    QUEUE_INFO=$(echo "$BUILDERS_PAGE" | grep -i "$ARCH" | head -1 || true)
    if [ -n "$QUEUE_INFO" ]; then
        echo "  $ARCH: $QUEUE_INFO"
    fi
done
echo ""

echo "===== 2. PPA Package Status ====="
echo "Fetching: $PPA_URL/+packages"
echo ""

PPA_PACKAGES=$(curl -sL "$PPA_URL/+packages")

# Find our package
if echo "$PPA_PACKAGES" | grep -q "$PACKAGE"; then
    echo "Package '$PACKAGE' found in PPA"
    echo ""

    if [ -n "$VERSION" ]; then
        echo "Checking for version $VERSION:"
        VERSION_INFO=$(echo "$PPA_PACKAGES" | grep -A 20 "$PACKAGE" | grep -A 15 "$VERSION" | head -20 || echo "Version not found")
        echo "$VERSION_INFO"
    else
        echo "All versions:"
        echo "$PPA_PACKAGES" | grep -A 10 "$PACKAGE" | head -15
    fi
else
    echo "Package '$PACKAGE' NOT found in PPA"
fi
echo ""

echo "===== 3. Ubuntu Series (Distributions) ====="
echo "Checking which Ubuntu releases have builds..."
echo ""

DISTS_URL="https://ppa.launchpadcontent.net/${PPA_OWNER}/${PPA_REPO}/ubuntu/dists/"
DISTS_PAGE=$(curl -sL "$DISTS_URL" 2>/dev/null || echo "")

if [ -n "$DISTS_PAGE" ]; then
    echo "Available Ubuntu series in this PPA:"
    echo "$DISTS_PAGE" | grep -oP 'href="\K[^/]+(?=/)' | grep -v 'Parent' | sort || echo "Could not parse distributions"
else
    echo "Could not fetch distribution list"
fi
echo ""

echo "===== 4. Build Records ====="
echo "Fetching build records for $PACKAGE..."
echo ""

BUILDS_URL="$PPA_URL/+builds?build_text=$PACKAGE&build_state=all"
BUILDS_PAGE=$(curl -sL "$BUILDS_URL")

if echo "$BUILDS_PAGE" | grep -q "$PACKAGE"; then
    echo "Recent builds for $PACKAGE:"
    echo ""

    # Extract build information (this is approximate due to HTML structure)
    echo "$BUILDS_PAGE" | grep -A 5 "$PACKAGE" | grep -E "(amd64|arm64|armhf|i386|Pending|Building|Successfully built|Failed|noble|jammy|focal)" | head -30
else
    echo "No build records found for $PACKAGE"
fi
echo ""

echo "===== 5. Recommendations ====="
echo ""

# Check if version-specific build exists
if [ -n "$VERSION" ]; then
    if echo "$PPA_PACKAGES" | grep -q "$VERSION"; then
        echo "✓ Version $VERSION found in PPA"

        # Check if it's still pending
        if echo "$PPA_PACKAGES" | grep -A 10 "$VERSION" | grep -qi "pending"; then
            echo "⏳ Build is PENDING"
            echo ""
            echo "   This means:"
            echo "   - Source was accepted by Launchpad"
            echo "   - Build job created but waiting for available builder"
            echo "   - Typical wait: 0-30 minutes, up to 2-3 hours during heavy load"
            echo ""
            echo "   Check builder queue above for current backlog"
            echo "   Visit $BUILDERS_URL for live status"
        elif echo "$PPA_PACKAGES" | grep -A 10 "$VERSION" | grep -qi "building"; then
            echo "🔨 Build is BUILDING"
            echo "   Click the build link to see live logs"
        elif echo "$PPA_PACKAGES" | grep -A 10 "$VERSION" | grep -qi "published"; then
            echo "✅ Build is PUBLISHED"
            echo "   Package should be available via apt"
        elif echo "$PPA_PACKAGES" | grep -A 10 "$VERSION" | grep -qi "fail"; then
            echo "❌ Build FAILED"
            echo "   Check build logs for errors"
        fi
    else
        echo "⚠ Version $VERSION NOT found in PPA"
        echo "   Either upload failed or version mismatch"
    fi
fi
echo ""

echo "Direct links:"
echo "  PPA packages: $PPA_URL/+packages"
echo "  Build records: $BUILDS_URL"
echo "  Builder queue: $BUILDERS_URL"
echo ""
