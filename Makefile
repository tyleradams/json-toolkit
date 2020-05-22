all : json-diff json-empty

json-diff : json-diff.go
	go fmt json-diff.go
	go build json-diff.go

json-empty : json-empty.go
	go fmt json-empty.go
	go build json-empty.go

clean :
	rm json-diff json-empty 2> /dev/null || true

test :
	./run-all-tests

install : all
	install csv-to-json /usr/local/bin
	install dsv-to-json /usr/local/bin
	install json-cat /usr/local/bin
	install json-diff /usr/local/bin
	install json-empty /usr/local/bin
	install json-format /usr/local/bin
	install json-to-csv /usr/local/bin
	install json-to-dsv /usr/local/bin
	install json-to-plot /usr/local/bin
	install json-to-xml /usr/local/bin
	install json-to-yaml /usr/local/bin
	install xml-to-json /usr/local/bin
	install yaml-to-json /usr/local/bin
