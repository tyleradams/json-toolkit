# JSON Toolkit

The JSON Toolkit is a set of CLI tools which use json as a lingua franca for working with structured data.
Some highlights include json-diff, which structuraly diffs two json files, and data converters between json and xml, yaml, csv, and dsv.

## Prerequsites

* Bash
* Go
* Python3
* [jq](https://stedolan.github.io/jq/)

## Getting Started

* git clone git@github.com:tyleradams/json-toolkit.git
* make
* make test
* sudo make install

## Tools

### json-diff
json-diff takes in two json files as arguments and returns a list of differences between the files.
If the json are structurally the same, the output will be an empty json array.

#### Output format
The output is a json encoded list of difference objects describing the difference between two json files.
##### Difference Object
A difference object has a required **path**, an optional **leftValue**, and an optional **rightValue**.
The **leftValue** and **rightValue** are the values of the json object at the **path** for the left file and right files respectively.
If there is no **leftValue**, this means the **path** does not exist for the left file, and similarly for the **rightValue** and right file.
###### Path
The **path** is the location of a particular a json value nested within a larger json value. If you were to access a value in Python at:
```
o["first_key"][0]["second_key"]
```
the equivalent json-diff path is
```
["first_key", 0, "second_key"]
```

#### Examples
##### File setup
json-diff operates on files, so here we create a few files we can use later.
```
$ echo '[]' > empty_array.json
$ echo '[1]' > single_element_array.json
```

##### Comparing equivalent files
```
$ json-diff empty_array.json empty_array.json
$
```

##### Comparing different files
```
$ json-diff empty_array.json single_element_array.json
[{"path":[0],"rightValue":1}]
```

### json-empty
#### Description
json-empty checks if the input is an empty json array. If so, it returns exit code 0 and an empty stdout
If the input is valid json but is not an empty array, json-empty returns exit code 1 and the returns the inputted string to stdout.
If the input is not valid json , json-empty returns exit code 2 and throws an error message to stderr.
#### Examples
##### Passing an empty JSON array into json-empty
```
$ echo '[]' | json-empty
$
```

##### Passing a non-empty JSON array into json-empty
```
$ echo '[1]' | json-empty
[1]
```

##### Passing a JSON string into json-empty
```
$ echo '"non-empty array input"' | json-empty
"non-empty array input"
```

##### Passing non-JSON into json-empty
```
$ echo 'this is not json' | json-empty
invalid character 'h' in literal true (expecting 'r')
```

### json-to-csv
#### Description
json-to-csv takes a json array of array of strings from stdin and formats the data as a csv on stdout.
#### Examples
```
$ echo '[["Single cell"]]' | json-to-csv
"Single Cell"
$ echo '[["Multiple", "cells", "but", "one", "row"]]' | json-to-csv
"Multiple","cells","but","one","row"
$ echo '[["Multiple", "cells"], ["and"], ["multiple", "rows"]]' | json-to-csv
"Multiple","cells"
"and"
"multiple","rows"
```

### json-to-dsv
#### Description
json-to-dsv takes a json array of array of strings from stdin, and a delmiter as the first argument, and formats the data as a dsv with the specified delimiter on stdout.
#### Examples
```
$ echo '[["Single cell"]]' | json-to-dsv :
Single cell
$ echo '[["Multiple", "cells", "but", "one", "row"]]' | json-to-dsv :
Multiple:cells:but:one:row
$ echo '[["Multiple", "cells"], ["and"], ["multiple", "rows"]]' | json-to-dsv :
Multiple:cells
and
multiple:rows
```

### json-to-xml
#### Description
json-to-xml takes json from stdin and formats the data as xml on stdout with a top level "root" tag.
#### Examples
```
$ echo '{"a": "b"}' | json-to-xml
<?xml version="1.0" encoding="utf-8"?>
<root>
    <a>b</a>
</root>
```

### json-to-yaml
#### Description
json-to-yaml takes json from stdin and formats the data as yaml on stdout.
#### Examples
```
$ echo '{"a": 1, "b": 2}' | json-to-yaml
a: 1
b: 2
```

### csv-to-json
#### Description
csv-to-json takes a csv from stdin and formats the data into a json array of array of strings.
#### Examples
```
$ echo Single cell | csv-to-json
[["Single cell"]]
$ echo Multiple,cells,but,one,row | csv-to-json
[["Multiple", "cells", "but", "one", "row"]]
$ echo -e Multiple,cells\\nand\\nmultiple,rows | csv-to-json
[["Multiple", "cells"], ["and"], ["multiple", "rows"]]
```


### dsv-to-json
#### Description
dsv-to-json takes a dsv file from stdin, the delimiter as the first argument, and formats the data into a json array of array of strings.
#### Examples
```
$ echo Single cell | dsv-to-json :
[["Single cell"]]
$ echo Multiple:cells:but:one:row | dsv-to-json :
[["Multiple", "cells", "but", "one", "row"]]
$ echo -e Multiple:cells\\nand\\nmultiple:rows | dsv-to-json :
[["Multiple", "cells"], ["and"], ["multiple", "rows"]]
```

### xml-to-json
#### Description
xml-to-json takes xml from stdin and formats the data as json on stdout.
#### Examples
```
$ echo '<a>b</a>' | xml-to-json
{"a": "b"}
```

### yaml-to-json
#### Description
yaml-to-json takes yaml from stdin and formats the data as json on stdout.
#### Examples
```
$ echo 'a: b' | yaml-to-json
{"a": "b"}
```
