package main

import "encoding/json"
import "fmt"
import "io/ioutil"
import "os"
import "reflect"

func min(a int, b int) int {
	if a < b {
		return a
	} else {
		return b
	}
}

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

func compare_slice(path []interface{}, anySlice1 interface{}, anySlice2 interface{}) []map[string]interface{} {
	slice1 := anySlice1.([]interface{})
	slice2 := anySlice2.([]interface{})
	if len(slice1) == len(slice2) {
		return []map[string]interface{}{}
	} else {
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
}

func compare_map(path []interface{}, anyMap1 interface{}, anyMap2 interface{}) []map[string]interface{} {
	map1 := anyMap1.(map[string]interface{})
	map2 := anyMap2.(map[string]interface{})
	diff := []map[string]interface{}{}
	for key, _ := range map1 {
		_, ok := map2[key]
		if ok {
			diff = append(diff, compare_object(append(path, key), map1[key], map2[key])...)
		} else {
			diff = append(diff, map[string]interface{}{
				"path":      append(path, key),
				"leftValue": map1[key],
			})
		}
	}
	for key, _ := range map2 {
		_, ok := map1[key]
		if !ok {
			diff = append(diff, map[string]interface{}{
				"path":       append(path, key),
				"rightValue": map2[key],
			})
		}
	}
	return diff
}

func compare_object(path []interface{}, json1 interface{}, json2 interface{}) []map[string]interface{} {
	m := map[reflect.Kind]func([]interface{}, interface{}, interface{}) []map[string]interface{}{
		reflect.Float64: compare_simple,
		reflect.Bool:    compare_simple,
		reflect.String:  compare_simple,
		reflect.Slice:   compare_slice,
		reflect.Map:     compare_map,
	}
	var type1 interface{}
	var type2 interface{}

	if json1 == nil {
		type1 = nil
	} else {
		type1 = reflect.TypeOf(json1).Kind()
	}

	if json2 == nil {
		type2 = nil
	} else {
		type2 = reflect.TypeOf(json2).Kind()
	}

	if type1 == type2 {
		if type1 == nil {
                return []map[string]interface{}{}
            } else {
                return m[type1.(reflect.Kind)](path, json1, json2)
            }
        } else {
            return []map[string]interface{}{
			{
				"path":       path,
				"leftValue":  json1,
				"rightValue": json2,
			},
		}
	}
}

func check(e error) {
	if e != nil {
		panic(e)
	}
}

func main() {
	file1, err := ioutil.ReadFile(os.Args[1])
	check(err)
	file2, err := ioutil.ReadFile(os.Args[2])
	check(err)

	var json1 interface{}
	var json2 interface{}
	err = json.Unmarshal(file1, &json1)
	check(err)

	err = json.Unmarshal(file2, &json2)
	check(err)

	diff := compare_object([]interface{}{}, json1, json2)

	output, err := json.Marshal(diff)
	fmt.Printf("%v\n", string(output))
}
