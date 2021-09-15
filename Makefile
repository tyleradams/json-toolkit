all : json-diff json-empty-array dependencies

json-diff : json-diff.go
	go fmt json-diff.go
	go build json-diff.go

json-empty-array : json-empty-array.go
	go fmt json-empty-array.go
	go build json-empty-array.go

# Only install if apt is on system, otherwise do nothing
# Using oneliner to avoid messing around with makefile if statements
dependencies : bash-dependencies python-dependencies

bash-dependencies:
	(! command -v apt > /dev/null;) || sudo apt install -y libpq-dev

python-dependencies : requirements.txt
	python3 -m pip install -r requirements.txt

clean :
	rm json-diff json-empty-array 2> /dev/null || true

lint:
	./run-linter

fmt :
	./run-formatter

test :
	./run-all-tests

install :
	install binary-to-json /usr/local/bin
	install csv-to-json /usr/local/bin
	install diff-to-json /usr/local/bin
	install dsv-to-json /usr/local/bin
	install jargs /usr/local/bin
	install json-objs-to-table /usr/local/bin
	install json-diff /usr/local/bin
	install json-empty-array /usr/local/bin
	install json-format /usr/local/bin
	install json-make-schema /usr/local/bin
	install json-run /usr/local/bin
	install json-sql /usr/local/bin
	install json-table-to-objs /usr/local/bin
	install json-to-binary /usr/local/bin
	install json-to-csv /usr/local/bin
	install json-to-dsv /usr/local/bin
	install json-to-logfmt /usr/local/bin
	install json-to-plot /usr/local/bin
	install json-to-xml /usr/local/bin
	install json-to-yaml /usr/local/bin
	install logfmt-to-json /usr/local/bin
	install python-to-json-ast /usr/local/bin
	install xml-to-json /usr/local/bin
	install yaml-to-json /usr/local/bin

deploy:
	git push
