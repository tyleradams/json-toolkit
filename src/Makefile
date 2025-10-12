SHELL = /bin/sh

# Tools and flags (user-overridable)
GO ?= go
INSTALL ?= install
INSTALL_PROGRAM ?= $(INSTALL)
MKDIR_P ?= mkdir -p
RM ?= rm -f

# Installation directories (should be passed from parent Makefile)
prefix ?= /usr/local
exec_prefix ?= $(prefix)
bindir ?= $(exec_prefix)/bin
DESTDIR ?=

# Programs to install
PROGRAMS = \
	binary-to-json \
	csv-to-json \
	diff-to-json \
	dsv-to-json \
	env-to-json \
	json-format \
	json-make-schema \
	json-objs-to-table \
	json-run \
	json-sql \
	json-table-to-objs \
	json-to-binary \
	json-to-csv \
	json-to-dsv \
	json-to-env \
	json-to-logfmt \
	json-to-plot \
	json-to-xml \
	json-to-yaml \
	logfmt-to-json \
	pjito \
	python-to-json-ast \
	xml-to-json \
	yaml-to-json

# Go programs (built separately in parent Makefile)
GO_PROGRAMS = json-diff

all: $(GO_PROGRAMS)

json-diff: json-diff.go
	$(GO) fmt json-diff.go
	$(GO) build json-diff.go


.PHONY: install
install:
	$(MKDIR_P) $(DESTDIR)$(bindir)
	@for prog in $(PROGRAMS); do \
		echo "  INSTALL  $$prog -> $(DESTDIR)$(bindir)/$$prog"; \
		$(INSTALL_PROGRAM) $$prog $(DESTDIR)$(bindir)/; \
	done

.PHONY: uninstall
uninstall:
	@for prog in $(PROGRAMS) $(GO_PROGRAMS); do \
		echo "  RM       $(DESTDIR)$(bindir)/$$prog"; \
		$(RM) $(DESTDIR)$(bindir)/$$prog; \
	done

.PHONY: all install uninstall
