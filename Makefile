SHELL = /bin/sh
.DEFAULT_GOAL := all

# Project metadata
PACKAGE ?= json-toolkit
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null | sed 's/^v//' || echo "dev")

# Tools and flags (user-overridable)
GO ?= go
PYTHON3 ?= python3
INSTALL ?= install
INSTALL_PROGRAM ?= $(INSTALL)
INSTALL_DATA ?= $(INSTALL) -m 644
MKDIR_P ?= mkdir -p
RM ?= rm -f

# Installation directories (GNU-style)
prefix ?= /usr/local
exec_prefix ?= $(prefix)
bindir ?= $(exec_prefix)/bin
datarootdir ?= $(prefix)/share
docdir ?= $(datarootdir)/doc/$(PACKAGE)
DESTDIR ?=

# Build directories
BUILDDIR := target

# Quiet by default; make V=1 for verbose
ifneq ($(V),1)
Q := @
else
Q :=
endif

# Go build targets
GO_SOURCES := src/json-diff.go src/logfmt-to-json.go src/json-to-logfmt.go
GO_BINARIES := $(BUILDDIR)/json-diff $(BUILDDIR)/logfmt-to-json $(BUILDDIR)/json-to-logfmt

all: $(GO_BINARIES)

$(BUILDDIR)/json-diff: src/json-diff.go
	@echo "  GO FMT  $<"
	$(Q)$(GO) fmt $<
	@echo "  GO BUILD $@"
	$(Q)$(MKDIR_P) $(BUILDDIR)
	$(Q)$(GO) build -o $@ $<

$(BUILDDIR)/logfmt-to-json: src/logfmt-to-json.go
	@echo "  GO FMT  $<"
	$(Q)$(GO) fmt $<
	@echo "  GO BUILD $@"
	$(Q)$(MKDIR_P) $(BUILDDIR)
	$(Q)$(GO) build -o $@ $<

$(BUILDDIR)/json-to-logfmt: src/json-to-logfmt.go
	@echo "  GO FMT  $<"
	$(Q)$(GO) fmt $<
	@echo "  GO BUILD $@"
	$(Q)$(MKDIR_P) $(BUILDDIR)
	$(Q)$(GO) build -o $@ $<

# Dependencies (optional - only if user wants)
.PHONY: dependencies
dependencies: python-dependencies

.PHONY: python-dependencies
python-dependencies: requirements.txt
	@echo "  PIP    installing Python dependencies"
	$(Q)$(PYTHON3) -m pip install -r requirements.txt

.PHONY: clean
clean:
	@echo "  CLEAN"
	$(Q)$(RM) -r $(BUILDDIR)

.PHONY: mostlyclean
mostlyclean: clean

.PHONY: distclean
distclean: clean

.PHONY: lint
lint:
	@echo "  LINT"
	$(Q)./run-linter

.PHONY: fmt format
fmt format:
	@echo "  FMT"
	$(Q)./run-formatter

.PHONY: check test
check test: all
	@echo "  TEST"
	$(Q)./run-all-tests

.PHONY: install
install: all
	@echo "  INSTALL"
	$(Q)$(MKDIR_P) $(DESTDIR)$(bindir)
	$(Q)$(MKDIR_P) $(DESTDIR)$(docdir)
	@echo "Installing Go binaries to $(DESTDIR)$(bindir)"
	$(Q)$(INSTALL_PROGRAM) $(BUILDDIR)/json-diff $(DESTDIR)$(bindir)/
	$(Q)$(INSTALL_PROGRAM) $(BUILDDIR)/logfmt-to-json $(DESTDIR)$(bindir)/
	$(Q)$(INSTALL_PROGRAM) $(BUILDDIR)/json-to-logfmt $(DESTDIR)$(bindir)/
	@echo "Installing Python/Bash utilities from src/"
	$(Q)$(MAKE) -C src prefix=$(prefix) DESTDIR=$(DESTDIR) install
	@echo "Installing documentation"
	$(Q)$(INSTALL_DATA) README.md $(DESTDIR)$(docdir)/
	$(Q)$(INSTALL_DATA) LICENSE $(DESTDIR)$(docdir)/

.PHONY: install-strip
install-strip: install
	@echo "  STRIP   $(DESTDIR)$(bindir)/json-diff"
	$(Q)strip $(DESTDIR)$(bindir)/json-diff || true
	$(Q)strip $(DESTDIR)$(bindir)/logfmt-to-json || true
	$(Q)strip $(DESTDIR)$(bindir)/json-to-logfmt || true

.PHONY: uninstall
uninstall:
	@echo "  UNINSTALL"
	$(Q)$(RM) $(DESTDIR)$(bindir)/json-diff
	$(Q)$(RM) $(DESTDIR)$(bindir)/logfmt-to-json
	$(Q)$(RM) $(DESTDIR)$(bindir)/json-to-logfmt
	$(Q)$(MAKE) -C src prefix=$(prefix) DESTDIR=$(DESTDIR) uninstall
	$(Q)$(RM) $(DESTDIR)$(docdir)/README.md
	$(Q)$(RM) $(DESTDIR)$(docdir)/LICENSE
	$(Q)-rmdir $(DESTDIR)$(docdir) 2>/dev/null || true

.PHONY: dist
dist: clean
	@echo "  DIST    $(PACKAGE)-$(VERSION).tar.gz"
	$(Q)git archive --format=tar --prefix=$(PACKAGE)-$(VERSION)/ HEAD | gzip -9 > $(PACKAGE)-$(VERSION).tar.gz

# Debian packaging targets
.PHONY: package
package:
	@echo "  PACKAGE Building Debian source package for $(VERSION)"
	$(Q)$(MKDIR_P) $(BUILDDIR)
	@echo "  GBP     Generating debian/changelog from git"
	$(Q)gbp dch --new-version=$(VERSION) --debian-tag='v%(version)s' --spawn-editor=never --git-author --distribution=noble 2>/dev/null || \
		(echo "$(PACKAGE) ($(VERSION)) noble; urgency=medium" > debian/changelog && \
		 echo "" >> debian/changelog && \
		 echo "  * Release $(VERSION)" >> debian/changelog && \
		 echo "" >> debian/changelog && \
		 echo " -- $(shell git config user.name) <$(shell git config user.email)>  $(shell date -R)" >> debian/changelog)
	$(Q)tar czf $(BUILDDIR)/$(PACKAGE)_$(VERSION).orig.tar.gz \
		--exclude=src/json-diff \
		--transform "s#^#$(PACKAGE)-$(VERSION)/#" \
		Makefile src go.mod go.sum vendor README.md LICENSE
	$(Q)cd $(BUILDDIR) && tar xf $(PACKAGE)_$(VERSION).orig.tar.gz
	$(Q)cp -r debian $(BUILDDIR)/$(PACKAGE)-$(VERSION)/debian
	$(Q)cd $(BUILDDIR)/$(PACKAGE)-$(VERSION) && debuild -S -sa -d -nc -k"$(DEBSIGN_KEY)"

.PHONY: publish
publish:
	debsign -k $(DEBSIGN_KEY) ./$(BUILDDIR)/$(PACKAGE)_$(VERSION)_source.changes
	dput code-faster ./$(BUILDDIR)/$(PACKAGE)_$(VERSION)_source.changes

.PHONY: help
help:
	@echo "JSON Toolkit - Makefile targets"
	@echo ""
	@echo "Build targets:"
	@echo "  all (default)       Build all Go binaries"
	@echo "  clean               Remove build artifacts"
	@echo "  fmt                 Format code (Go and Python)"
	@echo "  lint                Run linters"
	@echo ""
	@echo "Test targets:"
	@echo "  test, check         Run all tests"
	@echo ""
	@echo "Install targets:"
	@echo "  install             Install to $(prefix) (default: /usr/local)"
	@echo "  install-strip       Install and strip binaries"
	@echo "  uninstall           Remove installed files"
	@echo ""
	@echo "Packaging targets:"
	@echo "  dist                Create source tarball"
	@echo "  package             Build Debian package"
	@echo "  publish             Publish Debian package to PPA"
	@echo ""
	@echo "Variables:"
	@echo "  prefix=$(prefix)              Installation prefix"
	@echo "  DESTDIR=$(DESTDIR)            Staging directory for packaging"
	@echo "  V=1                          Enable verbose output"
	@echo "  VERSION=$(VERSION)           Package version"
	@echo ""
	@echo "Examples:"
	@echo "  make"
	@echo "  make test"
	@echo "  make prefix=/usr install"
	@echo "  make DESTDIR=/tmp/staging install"
	@echo "  make VERSION=1.2.0 package"

.PHONY: all
