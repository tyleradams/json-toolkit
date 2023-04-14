args = $(foreach a,$($(subst -,_,$1)_args),$(if $(value $a),$a="$($a)"))

all : json-diff json-empty-array dependencies

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
package :
	mkdir -p target
	tar czf target/json-toolkit_${version}.orig.tar.gz src --transform "s/src/json-toolkit-${version}/"
	(cd target; tar xf json-toolkit_${version}.orig.tar.gz;)
	cp -r debian target/json-toolkit-${version}/debian
	(cd target/json-toolkit-${version}; debuild -us -uc;)

publish:
	debsign -k 5DB475563E94EEAC666956FD31CA7EECE167B1C8 ./target/json-toolkit_${version}_amd64.changes
	dput -f code-faster ./target/json-toolkit_${version}_amd64.changes
