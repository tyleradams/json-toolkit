package main

import "encoding/json"
import "errors"
import "fmt"
import "io/ioutil"
import "os"
import "reflect"

func check(e error) {
	if e != nil {
		panic(e)
	}
}

func min(a int, b int) int {
	if a < b {
		return a
	}

	return b
}

type compare func(path []interface{}, v1 interface{}, v2 interface{}) []map[string]interface{}

func compareSimple(path []interface{}, v1 interface{}, v2 interface{}) []map[string]interface{} {
	if v1 == v2 {
		return []map[string]interface{}{}
	}

	return []map[string]interface{}{
		{
			"path":       path,
			"leftValue":  v1,
			"rightValue": v2,
		},
	}
}

func compareSlice(path []interface{}, v1 interface{}, v2 interface{}) []map[string]interface{} {
	slice1 := v1.([]interface{})
	slice2 := v2.([]interface{})

	m := []map[string]interface{}{}

	for i := 0; i < min(len(slice1), len(slice2)); i++ {
		i1 := slice1[i]
		i2 := slice2[i]
		new_path := make([]interface{}, len(path))
		copy(new_path, path)
		m = append(m, compareObject(append(new_path, i), i1, i2)...)
	}

	if len(slice1) > len(slice2) {
		for i := len(slice2); i < len(slice1); i++ {
			new_path := make([]interface{}, len(path))
			copy(new_path, path)
			m = append(m, map[string]interface{}{
				"path":      append(new_path, i),
				"leftValue": slice1[i],
			})
		}
	}

	if len(slice2) > len(slice1) {
		for i := len(slice1); i < len(slice2); i++ {
			new_path := make([]interface{}, len(path))
			copy(new_path, path)
			m = append(m, map[string]interface{}{
				"path":       append(new_path, i),
				"rightValue": slice2[i],
			})
		}
	}
	return m
}

func compareMap(path []interface{}, v1 interface{}, v2 interface{}) []map[string]interface{} {

	map1 := v1.(map[string]interface{})
	map2 := v2.(map[string]interface{})

	diff := []map[string]interface{}{}

	for key := range map1 {
		_, keyInMap2 := map2[key]
		if keyInMap2 {
			new_path := make([]interface{}, len(path))
			copy(new_path, path)
			diff = append(diff, compareObject(append(new_path, key), map1[key], map2[key])...)
		} else {
			new_path := make([]interface{}, len(path))
			copy(new_path, path)
			diff = append(diff, map[string]interface{}{
				"path":      append(new_path, key),
				"leftValue": map1[key],
			})
		}
	}

	for key := range map2 {
		_, keyInMap1 := map1[key]
		if !keyInMap1 {
			new_path := make([]interface{}, len(path))
			copy(new_path, path)
			diff = append(diff, map[string]interface{}{
				"path":       append(new_path, key),
				"rightValue": map2[key],
			})
		}
	}

	return diff
}

func compareObject(path []interface{}, object1 interface{}, object2 interface{}) []map[string]interface{} {
	// nil does not have a reflection type kind, so we need to check for this case first
	if object1 == nil || object2 == nil {
		return compareSimple(path, object1, object2)
	}

	// This cannot be defined outside because it makes an initialization loop
	var compares = map[reflect.Kind]compare{
		reflect.Float64: compareSimple,
		reflect.Bool:    compareSimple,
		reflect.String:  compareSimple,
		reflect.Slice:   compareSlice,
		reflect.Map:     compareMap,
	}

	var type1 reflect.Kind = reflect.TypeOf(object1).Kind()
	var type2 reflect.Kind = reflect.TypeOf(object2).Kind()

	if type1 != type2 {
		return compareSimple(path, object1, object2)
	} else if val, ok := compares[type1]; type1 == type2 && ok {
		return val(path, object1, object2)
	} else {
		panic(errors.New(fmt.Sprintf("IncompleteIfTree:type1:%v:type2:%v", type1, type2)))
	}
}

func main() {
	if len(os.Args) != 3 {
		fmt.Print(
			`Usage: json-diff FILE1 FILE2

OVERVIEW:
    json-diff reports differences between two json files as json.

    For each difference, json-diff reports the path in the json of the difference, the value in FILE1 (leftValue) (if present), and the value in FILE2 (rightValue) (if present).
    If a value is only present in FILE1, rightValue will not be present.
    If a value is only present in FILE2, leftValue will not be present.

PATH NOTATION:
    The path for a difference is an array of numbers and strings. Each number refers to an array index and each string refers to an object key.

    For example, [0, "a", 2] would refer to "foo" in the json value:
        [
            {
                "a": [
                    null,
                    null,
                    "foo"
                    ]
            }
        ]

OUTPUT SCHEMA:
    {
      "$schema": "http://json-schema.org/schema#",
      "items": {
        "properties": {
          "leftValue": {
            "type": ["null", "boolean", "object", "array", "number", "string"]
          },
          "path": {
            "type": "array",
            "contains": ["number", "string"]
          },
          "rightValue": {
            "type": ["null", "boolean", "object", "array", "number", "string"]
          }
        },
        "required": [
          "path"
        ],
        "type": "object"
      },
      "type": "array"
    }
`)
		os.Exit(1)
	}

	file1, err := ioutil.ReadFile(os.Args[1])
	check(err)
	file2, err := ioutil.ReadFile(os.Args[2])
	check(err)

	var object1 interface{}
	var object2 interface{}
	err = json.Unmarshal(file1, &object1)
	check(err)

	err = json.Unmarshal(file2, &object2)
	check(err)

	diff := compareObject([]interface{}{}, object1, object2)

	output, _ := json.Marshal(diff)
	fmt.Println(string(output))
	if len(diff) == 0 {
		os.Exit(0)
	}

	os.Exit(1)
}
