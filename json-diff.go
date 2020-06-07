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

type Compare func(path []interface{}, v1 interface{}, v2 interface{}) []map[string]interface{}

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
		m = append(m, compareObject(append(path, i), i1, i2)...)
	}

	if len(slice1) > len(slice2) {
		for i := len(slice2); i < len(slice1); i++ {
			m = append(m, map[string]interface{}{
				"path":      append(path, i),
				"leftValue": slice1[i],
			})
		}
	}

	if len(slice2) > len(slice1) {
		for i := len(slice1); i < len(slice2); i++ {
			m = append(m, map[string]interface{}{
				"path":       append(path, i),
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
			diff = append(diff, compareObject(append(path, key), map1[key], map2[key])...)
		} else {
			diff = append(diff, map[string]interface{}{
				"path":      append(path, key),
				"leftValue": map1[key],
			})
		}
	}

	for key := range map2 {
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

func compareObject(path []interface{}, object1 interface{}, object2 interface{}) []map[string]interface{} {
	// nil does not have a reflection type kind, so we need to check for this case first
	if object1 == nil || object2 == nil {
		return compareSimple(path, object1, object2)
	}

	// This cannot be defined outside because it makes an initialization loop
	var compare = map[reflect.Kind]Compare{
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
	} else if val, ok := compare[type1]; type1 == type2 && ok {
		return val(path, object1, object2)
	} else {
		panic(errors.New("IncompleteIfTree:type1:" + string(type1) + ":type2:" + string(type2)))
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

	diff := compareObject([]interface{}{}, object1, object2)

	output, _ := json.Marshal(diff)
	fmt.Printf("%v\n", string(output))
	if len(diff) == 0 {
		os.Exit(0)
	}

	os.Exit(1)
}
