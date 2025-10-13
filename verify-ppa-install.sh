#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-2.0.5}"
UBUNTU_VERSION="${2:-24.04}"
PPA_NAME="${PPA_NAME:-ppa:code-faster/ppa}"

echo "Testing PPA installation of json-toolkit $VERSION from $PPA_NAME"
echo "Ubuntu version: $UBUNTU_VERSION"

dockerfile=$(mktemp)
cat > "$dockerfile" <<DOCKERFILE
FROM ubuntu:$UBUNTU_VERSION

ENV DEBIAN_FRONTEND=noninteractive

# Add PPA and update
RUN apt-get update && apt-get install -y software-properties-common
RUN add-apt-repository -y $PPA_NAME
RUN apt-get update

# Check available version
RUN apt-cache policy json-toolkit
RUN apt-cache policy json-toolkit | grep -q "Candidate:.*$VERSION" || \
    (echo "ERROR: Expected version $VERSION not available in PPA" && exit 1)

# Install
RUN apt-get install -y json-toolkit

# Verify correct version installed
RUN dpkg -l json-toolkit | grep "^ii.*json-toolkit.*$VERSION"

# Verify binaries exist
RUN which json-diff
RUN json-diff --help || true
RUN which csv-to-json
RUN csv-to-json --help || true

# Basic smoke tests
RUN echo '[]' | csv-to-json
RUN echo '{"a":1}' | json-to-yaml
RUN echo 'a: 1' | yaml-to-json

CMD echo "All verifications passed!"
DOCKERFILE

echo "Building verification Docker image with --no-cache..."
if docker build --no-cache -f "$dockerfile" -t "json-toolkit-ppa-verify:$VERSION" .; then
    echo "✅ PPA installation verification PASSED for version $VERSION"
    rm "$dockerfile"
    exit 0
else
    echo "❌ PPA installation verification FAILED"
    echo ""
    echo "Checking Launchpad build status..."

    # Extract PPA owner and name from PPA_NAME (format: ppa:owner/name)
    PPA_OWNER=$(echo "$PPA_NAME" | sed 's/ppa:\([^/]*\).*/\1/')
    PPA_REPO=$(echo "$PPA_NAME" | sed 's/ppa:[^/]*\/\(.*\)/\1/')

    # Fetch PPA page and check for our package
    PPA_URL="https://launchpad.net/~${PPA_OWNER}/+archive/ubuntu/${PPA_REPO}/+packages"
    echo "Fetching: $PPA_URL"

    if command -v curl &> /dev/null; then
        BUILD_STATUS=$(curl -sL "$PPA_URL" | grep -A 20 "json-toolkit" | head -30)

        if echo "$BUILD_STATUS" | grep -q "$VERSION"; then
            echo ""
            echo "Found version $VERSION in PPA:"
            echo "$BUILD_STATUS" | grep -E "(Building|Failed|Published|Pending)" | head -5

            if echo "$BUILD_STATUS" | grep -qi "building"; then
                echo ""
                echo "⏳ Package is currently BUILDING on Launchpad"
                echo "   Wait a few more minutes and try again"
            elif echo "$BUILD_STATUS" | grep -qi "failed"; then
                echo ""
                echo "❌ Package BUILD FAILED on Launchpad"
                echo "   Check build logs at: $PPA_URL"
            elif echo "$BUILD_STATUS" | grep -qi "pending"; then
                echo ""
                echo "⏳ Package is PENDING in build queue"
                echo "   Wait a few more minutes and try again"
            fi
        else
            echo ""
            echo "Version $VERSION not found in PPA yet"
            echo "Latest version available: $(docker run --rm ubuntu:22.04 bash -c 'apt-get update -qq 2>/dev/null && apt-get install -y -qq software-properties-common 2>/dev/null && add-apt-repository -y '$PPA_NAME' 2>/dev/null && apt-get update -qq 2>/dev/null && apt-cache policy json-toolkit 2>/dev/null | grep Candidate' 2>/dev/null || echo 'unknown')"
        fi

        echo ""
        echo "Check full status at: $PPA_URL"
    else
        echo "curl not available - cannot check Launchpad status"
        echo "Check manually at: $PPA_URL"
    fi

    echo ""
    echo "Dockerfile saved at: $dockerfile"
    exit 1
fi
