package main

import "os"
import "fmt"
import "io/ioutil"
import "encoding/json"

func main() {
	if len(os.Args) != 1 {
		fmt.Print(
			`Usage: json-empty-array

OVERVIEW:
    json-empty-array does the following:
        if stdin is a json empty array:
            exit code 0
        if stdin is valid json, but not an empty array:
            exit code 1
            the json object on stdout
        if stdin is not valid json:
            exit code 2
            the error message on stderr

EXAMPLE USAGE:
    echo '[]' | json-empty-array

ADVANCED EXAMPLE USAGE:
    json-diff expected.json actual.json | json-empty-array || (echo "Tests did not pass"; exit 1;)
`)
		os.Exit(1)
	}

	bytes, _ := ioutil.ReadAll(os.Stdin)

	var dat interface{}
	err := json.Unmarshal(bytes, &dat)

	if err != nil {
		switch err.(type) {
		case *json.SyntaxError:
			println("JSON SYNTAX ERROR: " + err.Error())
			os.Exit(2)
		default:
			panic(err)
		}
	}

	ar, ok := dat.([]interface{})
	if ok && len(ar) == 0 {
		os.Exit(0)
	} else {
		output, _ := json.Marshal(dat)
		fmt.Println(string(output))
		os.Exit(1)
	}
}
