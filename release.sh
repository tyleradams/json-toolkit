#!/usr/bin/env bash
#
# SUPERSEDED by tools/release/release.sh -- use `make deploy VERSION=X.Y.Z`.
#
# This script's docker phases tested `make install` from the repo rather than
# the built package, so they were blind to the packaging bug that would have
# shipped 2.0.6 without its logfmt tools. The replacement builds a real .deb
# and asserts on its payload instead. Kept only so nothing that still calls
# this path breaks silently; delete it whenever you like.
#
set -euo pipefail

if [ "${JSON_TOOLKIT_ALLOW_LEGACY_RELEASE:-}" != 1 ]; then
    echo "release.sh is superseded. Use:  make deploy VERSION=X.Y.Z" >&2
    echo "(set JSON_TOOLKIT_ALLOW_LEGACY_RELEASE=1 to run this anyway)" >&2
    exit 1
fi

# ===== LOGGING SETUP =====
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/release-${TIMESTAMP}.log"

# Create logs directory
mkdir -p "$LOG_DIR"

# Redirect all output to log file AND console
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "Release log: $LOG_FILE"
echo "Started: $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PACKAGE_NAME="json-toolkit"
DOCKER_IMAGE_BUILD="ubuntu:24.04"
DOCKER_IMAGE_TEST="ubuntu:24.04"
PPA_NAME="${PPA_NAME:-ppa:code-faster/ppa}"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}========================================${NC}"
}

check_prerequisites() {
    log_section "Checking Prerequisites"

    local missing=()

    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi

    if ! command -v git &> /dev/null; then
        missing+=("git")
    fi

    if ! command -v debuild &> /dev/null; then
        log_warning "debuild not found (install devscripts)"
    fi

    if ! command -v debsign &> /dev/null; then
        log_warning "debsign not found (install devscripts)"
    fi

    if ! command -v dput &> /dev/null; then
        log_warning "dput not found"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

get_version_from_tag() {
    local version=$1
    echo "$version"
}

check_clean_working_tree() {
    log_info "Checking working tree status"

    if ! git diff-index --quiet HEAD --; then
        log_error "Working tree has uncommitted changes"
        log_error "Please commit or stash changes before releasing"
        git status --short
        exit 1
    fi

    log_success "Working tree is clean"
}

phase_1_local_build_test() {
    log_section "PHASE 1: Local Build and Test"

    log_info "Cleaning previous builds..."
    make clean

    log_info "Building all components..."
    make

    log_info "Running test suite..."
    make test

    log_success "Local build and test passed"
}

phase_2_docker_build_package() {
    log_section "PHASE 2: Build Debian Package in Docker"

    local dockerfile_build=$(mktemp)
    cat > "$dockerfile_build" <<'EOF'
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    build-essential \
    debhelper \
    dh-python \
    devscripts \
    golang-go \
    python3-all \
    python3-pip \
    python3-click \
    python3-dotenv \
    python3-psycopg2 \
    python3-pymysql \
    python3-yaml \
    python3-toml \
    python3-unidiff \
    python3-xmltodict \
    jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

RUN make clean && make
EOF

    log_info "Building Docker image for package building..."
    docker build -f "$dockerfile_build" -t "$PACKAGE_NAME-build:latest" .
    rm "$dockerfile_build"

    log_info "Extracting built package..."
    local container_id=$(docker create "$PACKAGE_NAME-build:latest")
    mkdir -p build/docker-output
    docker cp "$container_id:/build/target" build/docker-output/ || true
    docker rm "$container_id"

    log_success "Docker build completed"
}

phase_3_docker_install_test() {
    log_section "PHASE 3: Install and Test in Clean Docker Environment"

    local dockerfile_test=$(mktemp)
    cat > "$dockerfile_test" <<'EOF'
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    golang-go \
    jq \
    python3 \
    python3-pip \
    python3-click \
    python3-dotenv \
    python3-psycopg2 \
    python3-pymysql \
    python3-yaml \
    python3-toml \
    python3-unidiff \
    python3-xmltodict \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# Install from source
RUN make clean && make && make install prefix=/usr

# Run tests
RUN make test

# Verify installations
RUN which json-diff
RUN json-diff --help || true
RUN which csv-to-json
RUN csv-to-json --help || true

# Basic smoke tests
RUN echo '[]' | csv-to-json
RUN echo '{"a":1}' | json-to-yaml
RUN echo 'a: 1' | yaml-to-json
EOF

    log_info "Building test Docker image..."
    docker build -f "$dockerfile_test" -t "$PACKAGE_NAME-test:latest" .
    rm "$dockerfile_test"

    log_info "Running tests in Docker..."
    docker run --rm "$PACKAGE_NAME-test:latest" make test

    log_success "Docker installation and tests passed"
}

phase_4_git_publish() {
    log_section "PHASE 4: Git Publishing"

    local version=$1
    local tag="v$version"

    # Check if tag already exists
    if git rev-parse "$tag" >/dev/null 2>&1; then
        log_warning "Tag $tag already exists locally"

        # Check if it exists on remote
        if git ls-remote --tags origin | grep -q "refs/tags/$tag"; then
            log_success "Tag $tag already pushed to origin (idempotent - skipping)"
        else
            log_info "Pushing existing tag to origin..."
            git push origin "$tag"
            log_success "Tag pushed to origin"
        fi
    else
        log_info "Creating annotated git tag: $tag"
        local key_id="${GPG_KEY:-${DEBSIGN_KEY:-}}"
        if [ -n "$key_id" ]; then
            git tag -s -u "$key_id" -a "$tag" -m "Release $version"
            log_info "Created signed tag with key $key_id"
        else
            git tag -a "$tag" -m "Release $version"
            log_warning "Created unsigned tag (set GPG_KEY or DEBSIGN_KEY to sign)"
        fi

        log_info "Pushing to origin..."
        git push origin "$(git branch --show-current)"
        git push origin "$tag"

        log_success "Git publishing completed"
    fi
}

phase_5_ppa_publish() {
    log_section "PHASE 5: PPA Publishing"

    if [ -z "${DEBSIGN_KEY:-}" ]; then
        log_error "DEBSIGN_KEY environment variable not set"
        log_info "Export your GPG key ID: export DEBSIGN_KEY=YOUR_KEY_ID"
        exit 1
    fi

    log_info "Building source package..."
    make package

    log_info "Signing package..."
    make publish DEBSIGN_KEY="$DEBSIGN_KEY"

    log_success "PPA publishing completed"
    log_warning "Note: It may take 5-30 minutes for the package to be available in the PPA"
}

phase_6_ppa_verify() {
    log_section "PHASE 6: PPA Installation Verification"

    local version=$1

    log_warning "Waiting 2 minutes for PPA to process package..."
    sleep 120

    local dockerfile_verify=$(mktemp)
    cat > "$dockerfile_verify" <<EOF
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Add PPA and install
RUN apt-get update && apt-get install -y software-properties-common
RUN add-apt-repository -y $PPA_NAME
RUN apt-get update
RUN apt-get install -y $PACKAGE_NAME

# Verify installation
RUN which json-diff
RUN json-diff --help || true
RUN which csv-to-json
RUN csv-to-json --help || true

# Basic smoke tests
RUN echo '[]' | csv-to-json
RUN echo '{"a":1}' | json-to-yaml
RUN echo 'a: 1' | yaml-to-json

CMD echo "All verifications passed!"
EOF

    log_info "Building PPA verification Docker image..."
    if docker build -f "$dockerfile_verify" -t "$PACKAGE_NAME-ppa-verify:latest" .; then
        log_success "PPA installation verification passed"
        rm "$dockerfile_verify"
    else
        log_error "PPA installation verification failed"
        log_info "The package may not be published yet. Try running this again in 10-30 minutes:"
        log_info "  docker build -f $dockerfile_verify -t $PACKAGE_NAME-ppa-verify:latest ."
        exit 1
    fi
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] VERSION

Release script for $PACKAGE_NAME

OPTIONS:
    -h, --help              Show this help message
    -s, --skip-phase PHASE  Skip specific phase (1-6)
    --skip-ppa             Skip PPA publishing and verification (phases 5-6)
    --local-only           Only run local build and tests (phase 1)
    --docker-only          Only run Docker build and tests (phases 2-3)

PHASES:
    1. Local build and test
    2. Docker package build
    3. Docker install and test
    4. Git publishing (tag and push)
    5. PPA publishing
    6. PPA verification (from published package)

VERSION:
    Semantic version number (e.g., 1.2.0)

ENVIRONMENT VARIABLES:
    DEBSIGN_KEY    GPG key ID for signing packages (required for PPA)
    PPA_NAME       PPA to publish to (default: ppa:code-faster/ppa)

EXAMPLES:
    # Full release
    $0 1.2.0

    # Local testing only
    $0 --local-only 1.2.0

    # Release without PPA
    $0 --skip-ppa 1.2.0

    # Skip phase 2 (Docker build)
    $0 --skip-phase 2 1.2.0

LOGS:
    All output is automatically saved to: $LOG_DIR/release-<timestamp>.log
EOF
}

main() {
    local skip_phases=()
    local version=""
    local local_only=false
    local docker_only=false
    local skip_ppa=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -s|--skip-phase)
                skip_phases+=("$2")
                shift 2
                ;;
            --skip-ppa)
                skip_ppa=true
                shift
                ;;
            --local-only)
                local_only=true
                shift
                ;;
            --docker-only)
                docker_only=true
                shift
                ;;
            *)
                if [ -z "$version" ]; then
                    version=$1
                else
                    log_error "Unknown option: $1"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Validate version
    if [ -z "$version" ]; then
        log_error "Version number required"
        usage
        exit 1
    fi

    if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Version must be in format X.Y.Z (e.g., 1.2.0)"
        exit 1
    fi

    log_section "Starting Release Process for v$version"

    check_prerequisites

    # Ensure working tree is clean (no uncommitted changes)
    check_clean_working_tree

    # Run phases based on flags
    if [ "$local_only" = true ]; then
        phase_1_local_build_test
        log_success "Local-only release checks completed!"
        exit 0
    fi

    if [ "$docker_only" = true ]; then
        phase_2_docker_build_package
        phase_3_docker_install_test
        log_success "Docker-only release checks completed!"
        exit 0
    fi

    # Full release pipeline
    [[ ! " ${skip_phases[*]} " =~ " 1 " ]] && phase_1_local_build_test
    [[ ! " ${skip_phases[*]} " =~ " 2 " ]] && phase_2_docker_build_package
    [[ ! " ${skip_phases[*]} " =~ " 3 " ]] && phase_3_docker_install_test

    if [ "$skip_ppa" = false ]; then
        [[ ! " ${skip_phases[*]} " =~ " 4 " ]] && phase_4_git_publish "$version"
        [[ ! " ${skip_phases[*]} " =~ " 5 " ]] && phase_5_ppa_publish
        [[ ! " ${skip_phases[*]} " =~ " 6 " ]] && phase_6_ppa_verify "$version"
    else
        [[ ! " ${skip_phases[*]} " =~ " 4 " ]] && phase_4_git_publish "$version"
        log_warning "Skipping PPA publishing and verification"
    fi

    log_section "RELEASE COMPLETE! 🎉"
    log_success "Version $version has been successfully released"

    cat <<EOF

Next steps:
  - Verify the release at: https://github.com/tyleradams/json-toolkit/releases/tag/v$version
  - Monitor PPA build status: https://launchpad.net/~code-faster/+archive/ubuntu/ppa
  - Test installation: sudo apt update && sudo apt install json-toolkit

Release log saved to: $LOG_FILE

EOF
}

# Run main
main "$@"
