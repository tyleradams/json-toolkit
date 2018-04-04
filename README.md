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

## Tools

### json-diff
json-diff takes in two json files as arguments and returns a list of differences between the files.
If the json are structurally the same, the output will be an empty json array.

#### Output format
The output is a json encoded list of difference objects describing the difference between two json files.
##### Difference Object
A difference object has a required path, an optional leftValue, and an optional rightValue.
The leftValue and rightValues are the values of the json object at the path for the left file and right files respectively.
If there is no leftValue, this means the path does not exist for the left file, and similarly for the rightValue and right file.
###### Path
The path is the location of a particular a json value nested within a larger json value.
In json-diff, this is encoded as a json array of integers or strings.
This notation is similar to the path notation used by (and plagarized from) jq.
The primary difference is our paths are arrays whereas jq uses . delimited strings
####### Example Path
In the object
```
[
    0,
    {
        "a": [
            -1
        ],
    }
]
```
-1 can be found at [1, "a", 0].
This path should be read as take the second element of top level array.
For this value, which is an object, take the value corresponding to the "a" key.
For this value, which is an array, take the first element.
This final value is the one found at [1, "a", 0].
#### Examples
##### File setup
json-diff operates on files, so here we create a few files we can use later.
```
echo '[]' > empty_array.json
cp empty_array.json other_empty_array.json
echo '[1]' > non_empty_array.json
```

##### Comparing equivalent files
```
json_diff empty_array.json empty_array.json
json_diff empty_array.json other_empty_array.json
json_diff non_empty_array.json non_empty_array.json
```

##### Comparing different files
```
json_diff empty_array.json non_empty_array.json
```

### json-empty
#### Description
json-empty checks if the input is an empty json array. If so, it returns exit code 0 and an empty stdout
If the input is valid json but is not an empty array, json-empty returns exit code 1 and the returns the inputted string to stdout.
If the input is not valid json , json-empty returns exit code 2 and throws an error message to stderr.
#### Examples
##### Passing an empty JSON array into json-empty
```
echo '[]' | json-empty
```

##### Passing a non-empty JSON array into json-empty
echo '[1]' | json-empty

##### Passing a JSON string into json-empty
```
echo '"non-empty array input"' | json-empty
```

##### Passing non-JSON into json-empty
```
echo 'this is not json' | json-empty
```
