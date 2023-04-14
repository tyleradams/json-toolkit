
all : json-diff json-empty-array

json-diff : json-diff.go
	go fmt json-diff.go
	go build json-diff.go

json-empty-array : json-empty-array.go
	go fmt json-empty-array.go
	go build json-empty-array.go

install :
	mkdir -p $(DESTDIR)$(prefix)/bin
	install binary-to-json $(DESTDIR)$(prefix)/bin
	install csv-to-json $(DESTDIR)$(prefix)/bin
	install diff-to-json $(DESTDIR)$(prefix)/bin
	install dsv-to-json $(DESTDIR)$(prefix)/bin
	install env-to-json $(DESTDIR)$(prefix)/bin
	install generate-json-diff-results $(DESTDIR)$(prefix)/bin
	install generate-test-results $(DESTDIR)$(prefix)/bin
	install json-diff $(DESTDIR)$(prefix)/bin
	install json-empty-array $(DESTDIR)$(prefix)/bin
	install json-make-schema $(DESTDIR)$(prefix)/bin
	install json-run $(DESTDIR)$(prefix)/bin
	install json-sql $(DESTDIR)$(prefix)/bin
	install json-table-to-objs $(DESTDIR)$(prefix)/bin
	install json-to-binary $(DESTDIR)$(prefix)/bin
	install json-to-csv $(DESTDIR)$(prefix)/bin
	install json-to-dsv $(DESTDIR)$(prefix)/bin
	install json-to-env $(DESTDIR)$(prefix)/bin
	install json-to-logfmt $(DESTDIR)$(prefix)/bin
	install json-to-xml $(DESTDIR)$(prefix)/bin
	install json-to-yaml $(DESTDIR)$(prefix)/bin
	install logfmt-to-json $(DESTDIR)$(prefix)/bin
	install pjito $(DESTDIR)$(prefix)/bin
	install python-to-json-ast $(DESTDIR)$(prefix)/bin
	install xml-to-json $(DESTDIR)$(prefix)/bin
	install yaml-to-json $(DESTDIR)$(prefix)/bin
