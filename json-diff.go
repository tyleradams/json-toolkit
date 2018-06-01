package main

import "encoding/json"
import "errors"
import "fmt"
import "io/ioutil"
import "os"
import "reflect"

// panic if e is non-nil
func check(e error) {
	if e != nil {
		panic(e)
	}
}

// Standard mathematical min function
func min(a int, b int) int {
	if a < b {
		return a
	} else {
		return b
	}
}

// Compares two objects and returns a list of differences relative to the json path
// If the objects are the same, an empty list is returned
// If the objects are different, a list with a single element is returned
func compare_simple(path []interface{}, simple1 interface{}, simple2 interface{}) []map[string]interface{} {
	if simple1 == simple2 {
		return []map[string]interface{}{}
	} else {
		return []map[string]interface{}{
			{
				"path":       path,
				"leftValue":  simple1,
				"rightValue": simple2,
			},
		}
	}
}

// Compares two slices index by index and returns a list of differences relative to the json path
// If the slices are the same, an empty list is returned
// If the slices differ at an index, a difference is returned specifying the value in each slice
// If one slice is longer than another, a difference is returned for each index in one slice and not the other
func compare_slice(path []interface{}, slice1 []interface{}, slice2 []interface{}) []map[string]interface{} {
	l := min(len(slice1), len(slice2))
	m := []map[string]interface{}{}
	for i := 0; i < l; i++ {
		i1 := slice1[i]
		i2 := slice2[i]
		m = append(m, compare_object(append(path, i), i1, i2)...)
	}
	if len(slice1) > len(slice2) {
		for i := l; i < len(slice1); i++ {
			m = append(m, map[string]interface{}{
				"path":      append(path, i),
				"leftValue": slice1[i],
			})
		}
	} else if len(slice2) > len(slice1) {
		for i := l; i < len(slice2); i++ {
			m = append(m, map[string]interface{}{
				"path":       append(path, i),
				"rightValue": slice2[i],
			})
		}
	}
	return m
}

// Compares two maps key by key and returns a list of differences relative to the json path
// If the maps are the same, an empty list is returned
// If the maps differ at a key, a difference is returned specifying the value in each map
// If one map has keys which are not in the another, a difference is returned for each key in one map and not the other
func compare_map(path []interface{}, map1 map[string]interface{}, map2 map[string]interface{}) []map[string]interface{} {
	diff := []map[string]interface{}{}
	for key, _ := range map1 {
		_, keyInMap2 := map2[key]
		if keyInMap2 {
			diff = append(diff, compare_object(append(path, key), map1[key], map2[key])...)
		} else {
			diff = append(diff, map[string]interface{}{
				"path":      append(path, key),
				"leftValue": map1[key],
			})
		}
	}
	for key, _ := range map2 {
		_, keyInMap1 := map1[key]
		if !keyInMap1 {
			diff = append(diff, map[string]interface{}{
				"path":       append(path, key),
				"rightValue": map2[key],
			})
		}
	}
	return diff
}

// Compares two objects and returns a list of differences relative to the json path
// If the objects are the same, an empty list is returned
// If the objects are different types, returns a simple difference between the objects
// If the objects are the same type, it
func compare_object(path []interface{}, object1 interface{}, object2 interface{}) []map[string]interface{} {
	// nil does not have a reflection type kind, so it's easier to hardcode this special case
	if object1 == nil || object2 == nil {
		return compare_simple(path, object1, object2)
	}

	var type1 reflect.Kind
	var type2 reflect.Kind

	type1 = reflect.TypeOf(object1).Kind()
	type2 = reflect.TypeOf(object2).Kind()

	if type1 == type2 {
		if type1 == reflect.Float64 {
			return compare_simple(path, object1, object2)
		} else if type1 == reflect.Bool {
			return compare_simple(path, object1, object2)
		} else if type1 == reflect.String {
			return compare_simple(path, object1, object2)
		} else if type1 == reflect.Slice {
			return compare_slice(path, object1.([]interface{}), object2.([]interface{}))
		} else if type1 == reflect.Map {
			return compare_map(path, object1.(map[string]interface{}), object2.(map[string]interface{}))
		} else {
			panic(errors.New("Type not found: " + string(type1)))
		}
	} else {
		return compare_simple(path, object1, object2)
	}
}

func main() {
	if len(os.Args) != 3 {
		fmt.Println("Usage: json-diff file1 file2")
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

	diff := compare_object([]interface{}{}, object1, object2)

	output, _ := json.Marshal(diff)
	fmt.Printf("%v\n", string(output))
	if len(diff) == 0 {
		os.Exit(0)
	} else {
		os.Exit(1)
	}
}
