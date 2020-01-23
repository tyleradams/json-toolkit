package main

import "os"
import "fmt"
import "io/ioutil"
import "encoding/json"

// If the input is an empty json array.
//   Returns exit code 0
//   Stdout is empty
//   Stderr is empty
// If the input is valid json, but not an empty array
//   Returns exit code 1
//   Stdout is the input
//   Stderr is empty
// If the input is valid json, but not an empty array
//   Returns exit code 2
//   Stdout is empty
//   Stderr is a go stacktrace
func main() {
	bytes, _ := ioutil.ReadAll(os.Stdin)

	var dat interface{}
	err := json.Unmarshal(bytes, &dat)

	if err != nil {
		switch err.(type) {
		case *json.SyntaxError:
			fmt.Println(err.Error())
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
