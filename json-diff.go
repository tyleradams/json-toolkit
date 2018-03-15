package main

import "encoding/json"
import "fmt"
import "io/ioutil"
import "os"
import "reflect"

type any interface{}

func min(a int, b int) int {
	if a < b {
		return a
	} else {
		return b
	}
}

func compare_simple(path []any, simple1 any, simple2 any) []map[string]any {
	if simple1 == simple2 {
		return []map[string]any{}
	} else {
		return []map[string]any{
			{
				"path":       path,
				"leftValue":  simple1,
				"rightValue": simple2,
			},
		}
	}
}

func compare_slice(path []any, anySlice1 any, anySlice2 any) []map[string]any {
	slice1 := anySlice1.([]interface{})
	slice2 := anySlice2.([]interface{})
	if len(slice1) == len(slice2) {
		return []map[string]any{}
	} else {
		l := min(len(slice1), len(slice2))
		m := []map[string]any{}
		for i := 0; i < l; i++ {
			i1 := slice1[i]
			i2 := slice2[i]
			m = append(m, compare_any(append(path, i), i1, i2)...)
		}
		if len(slice1) > len(slice2) {
			for i := l; i < len(slice1); i++ {
				m = append(m, map[string]any{
					"path":      append(path, i),
					"leftValue": slice1[i],
				})
			}
		} else if len(slice2) > len(slice1) {
			for i := l; i < len(slice2); i++ {
				m = append(m, map[string]any{
					"path":       append(path, i),
					"rightValue": slice2[i],
				})
			}
		}
		return m
	}
}

func compare_map(path []any, anyMap1 any, anyMap2 any) []map[string]any {
	map1 := anyMap1.(map[string]interface{})
	map2 := anyMap2.(map[string]interface{})
	diff := []map[string]any{}
	for key, _ := range map1 {
		_, ok := map2[key]
		if ok {
			diff = append(diff, compare_any(append(path, key), map1[key], map2[key])...)
		} else {
			diff = append(diff, map[string]any{
				"path":      append(path, key),
				"leftValue": map1[key],
			})
		}
	}
	for key, _ := range map2 {
		_, ok := map1[key]
		if !ok {
			diff = append(diff, map[string]any{
				"path":       append(path, key),
				"rightValue": map2[key],
			})
		}
	}
	return diff
}

func compare_any(path []any, json1 any, json2 any) []map[string]any {
	m := map[reflect.Kind]func([]any, any, any) []map[string]any{
		reflect.Float64: compare_simple,
		reflect.Bool:    compare_simple,
		reflect.String:  compare_simple,
		reflect.Slice:   compare_slice,
		reflect.Map:     compare_map,
	}
	t1 := reflect.TypeOf(json1).Kind()
	t2 := reflect.TypeOf(json2).Kind()

	if t1 == t2 {
		return m[t1](path, json1, json2)
	} else {
		return []map[string]any{
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

	var json1 any
	var json2 any
	err = json.Unmarshal(file1, &json1)
	check(err)

	err = json.Unmarshal(file2, &json2)
	check(err)

	diff := compare_any([]any{}, json1, json2)

	output, err := json.Marshal(diff)
	fmt.Printf("%v\n", string(output))
}
