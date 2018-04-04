# JSON Toolkit

This is a collection of CLI tools to help manipulate json files in a UNIX-like environment.

## Prerequsites

* UNIX-like operating system
* Bash
* Go
* Python3
* [jq](https://stedolan.github.io/jq/)

## Getting Started

* Clone the repository
* make
* ./run-all-tests - On success this should return nothing
* sudo make install

## Examples

### json-empty
#### Passing an empty JSON array into json empty
```
echo '[]' | json-empty
```

#### Passing a non-empty JSON array into json empty
echo '[1]' | json-empty

#### Passing a JSON string into json empty
```
echo '"non-empty array input"' | json-empty
```

#### Passing non-JSON into json empty
```
echo 'this is not json' | json-empty
```

### json-diff

#### Setup
JSON diff operates on files, so here we create a few files we can use later.
```
echo '[]' > empty_array.json
cp empty_array.json other_empty_array.json
echo '[1]' > non_empty_array.json
```

#### Comparing equivalent files
```
json_diff empty_array.json empty_array.json
json_diff empty_array.json other_empty_array.json
json_diff non_empty_array.json non_empty_array.json
```

#### Comparing different files
```
json_diff empty_array.json non_empty_array.json
```
