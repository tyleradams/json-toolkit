package main

import "os"
import "fmt"
import "io/ioutil"
import "encoding/json"

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
