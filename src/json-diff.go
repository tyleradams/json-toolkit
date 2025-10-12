package main

import "encoding/json"
import "errors"
import "flag"
import "fmt"
import "io/ioutil"
import "os"
import "path/filepath"
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
	app := filepath.Base(os.Args[0])

	fs := flag.NewFlagSet(app, flag.ContinueOnError)
	fs.SetOutput(os.Stderr)

	fs.Usage = func() {
		fmt.Fprintf(os.Stderr, "%s - compare two JSON files and report differences\n\n", app)
		fmt.Fprintf(os.Stderr, "Usage:\n  %s [flags] FILE1 FILE2\n\n", app)
		fmt.Fprintln(os.Stderr, "Overview:")
		fmt.Fprintln(os.Stderr, "  json-diff reports differences between two JSON files as JSON.")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "  For each difference, json-diff reports the path, the value in FILE1")
		fmt.Fprintln(os.Stderr, "  (leftValue) if present, and the value in FILE2 (rightValue) if present.")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "Path Notation:")
		fmt.Fprintln(os.Stderr, "  The path is an array of numbers and strings. Each number refers to an")
		fmt.Fprintln(os.Stderr, "  array index and each string refers to an object key.")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "  Example: [0, \"a\", 2] refers to \"foo\" in:")
		fmt.Fprintln(os.Stderr, "    [{\"a\": [null, null, \"foo\"]}]")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "Exit Codes:")
		fmt.Fprintln(os.Stderr, "  0 - Files are identical")
		fmt.Fprintln(os.Stderr, "  1 - Files differ")
		fmt.Fprintln(os.Stderr, "  2 - Error occurred")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "Flags:")
		fmt.Fprintln(os.Stderr, "  -h, -help    show help")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "Examples:")
		fmt.Fprintf(os.Stderr, "  %s old.json new.json\n", app)
		fmt.Fprintf(os.Stderr, "  %s config1.json config2.json | jq '.'\n", app)
	}

	// Support GNU-style --help explicitly
	for _, a := range os.Args[1:] {
		if a == "--help" {
			fs.Usage()
			os.Exit(0)
		}
	}

	if err := fs.Parse(os.Args[1:]); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			os.Exit(0)
		}
		os.Exit(2)
	}

	if fs.NArg() != 2 {
		fmt.Fprintln(os.Stderr, "error: requires exactly 2 file arguments")
		fs.Usage()
		os.Exit(2)
	}

	file1Path := fs.Arg(0)
	file2Path := fs.Arg(1)

	file1, err := ioutil.ReadFile(file1Path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error reading %s: %v\n", file1Path, err)
		os.Exit(2)
	}

	file2, err := ioutil.ReadFile(file2Path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error reading %s: %v\n", file2Path, err)
		os.Exit(2)
	}

	var object1 interface{}
	var object2 interface{}

	err = json.Unmarshal(file1, &object1)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error parsing %s: %v\n", file1Path, err)
		os.Exit(2)
	}

	err = json.Unmarshal(file2, &object2)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error parsing %s: %v\n", file2Path, err)
		os.Exit(2)
	}

	diff := compareObject([]interface{}{}, object1, object2)

	output, _ := json.Marshal(diff)
	fmt.Println(string(output))

	if len(diff) == 0 {
		os.Exit(0)
	}

	os.Exit(1)
}
