all : json-diff json-empty

json-diff :
	 go build json-diff.go

json-empty :
	 go build json-empty.go

clean :
	 rm json-diff json-empty 2> /dev/null || true
