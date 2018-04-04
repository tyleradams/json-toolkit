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

## Example usage

Should return nothing with exit code 0
```
echo '[]' | json-empty
```

Should return '"non-empty array input"' with exit code 1
```
echo '"non-empty array input"' | json-empty
```

```
echo '[]' > empty_array.json
echo '[1]' > non_empty_array.json
json_diff empty_array.json empty_array.json
json_diff non_empty_array.json non_empty_array.json
json_diff empty_array.json non_empty_array.json
```
