args = $(foreach a,$($(subst -,_,$1)_args),$(if $(value $a),$a="$($a)"))

all : move json-diff json-empty-array dependencies

json-diff : src/json-diff.go
	go fmt src/json-diff.go
	go build -o target/json-diff src/json-diff.go

json-empty-array : src/json-empty-array.go
	go fmt src/json-empty-array.go
	go build -o target/json-empty-array src/json-empty-array.go

# Only install if apt is on system, otherwise do nothing
# Using oneliner to avoid messing around with makefile if statements
dependencies : bash-dependencies python-dependencies

bash-dependencies:
	(! command -v apt > /dev/null;) || sudo apt install -y libpq-dev

python-dependencies : requirements.txt
	python3 -m pip install -r requirements.txt

clean :
	rm -rf target

lint:
	./run-linter

fmt :
	./run-formatter

test :
	./run-all-tests

movet :
	mkdir -p target/json-toolkit-${version}
	cp src/binary-to-json target
	cp -r debian target/json-toolkit-${version}/debian
tarball: move
	tar czf target/json-toolkit_${version}.orig.tar.gz target/json-toolkit-${version}
package: tarball
	(cd target/json-toolkit-${version} && debuild -uc -us;)

move :
	cp src/binary-to-json target
	cp src/csv-to-json target
	cp src/diff-to-json target
	cp src/dsv-to-json target
	cp src/env-to-json target
	cp src/json-objs-to-table target
	cp src/json-format target
	cp src/json-make-schema target
	cp src/json-run target
	cp src/json-sql target
	cp src/json-table-to-objs target
	cp src/json-to-binary target
	cp src/json-to-csv target
	cp src/json-to-dsv target
	cp src/json-to-env target
	cp src/json-to-logfmt target
	cp src/json-to-plot target
	cp src/json-to-xml target
	cp src/json-to-yaml target
	cp src/logfmt-to-json target
	cp src/python-to-json-ast target
	cp src/xml-to-json target
	cp src/yaml-to-json target
install :
	install target/binary-to-json /usr/local/bin
	install target/csv-to-json /usr/local/bin
	install target/diff-to-json /usr/local/bin
	install target/dsv-to-json /usr/local/bin
	install target/env-to-json /usr/local/bin
	install target/json-objs-to-table /usr/local/bin
	install target/json-diff /usr/local/bin
	install target/json-empty-array /usr/local/bin
	install target/json-format /usr/local/bin
	install target/json-make-schema /usr/local/bin
	install target/json-run /usr/local/bin
	install target/json-sql /usr/local/bin
	install target/json-table-to-objs /usr/local/bin
	install target/json-to-binary /usr/local/bin
	install target/json-to-csv /usr/local/bin
	install target/json-to-dsv /usr/local/bin
	install target/json-to-env /usr/local/bin
	install target/json-to-logfmt /usr/local/bin
	install target/json-to-plot /usr/local/bin
	install target/json-to-xml /usr/local/bin
	install target/json-to-yaml /usr/local/bin
	install target/logfmt-to-json /usr/local/bin
	install target/python-to-json-ast /usr/local/bin
	install target/xml-to-json /usr/local/bin
	install target/yaml-to-json /usr/local/bin
publish:
	dput -f code-faster ./json-toolkit_${version}_source.changes
