package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"

	"github.com/go-logfmt/logfmt"
)

const version = "3.0.0"

func main() {
	helpFlag := flag.Bool("help", false, "show help")
	hFlag := flag.Bool("h", false, "show help")
	flag.Parse()

	if *helpFlag || *hFlag {
		showHelp()
		os.Exit(0)
	}

	// Read JSON array from stdin
	var data []map[string]interface{}
	decoder := json.NewDecoder(os.Stdin)
	if err := decoder.Decode(&data); err != nil {
		fmt.Fprintf(os.Stderr, "Error: Invalid JSON: %v\n", err)
		os.Exit(1)
	}

	// Convert each object to logfmt
	encoder := logfmt.NewEncoder(os.Stdout)
	for _, record := range data {
		for key, value := range record {
			if err := encoder.EncodeKeyval(key, value); err != nil {
				fmt.Fprintf(os.Stderr, "Error encoding logfmt: %v\n", err)
				os.Exit(1)
			}
		}
		if err := encoder.EndRecord(); err != nil {
			fmt.Fprintf(os.Stderr, "Error writing logfmt: %v\n", err)
			os.Exit(1)
		}
	}
}

func showHelp() {
	fmt.Printf(`json-to-logfmt - convert JSON array to logfmt format (version %s)

Usage:
  json-to-logfmt [flags]

Overview:
  json-to-logfmt reads a JSON array of objects from stdin and outputs
  logfmt-formatted lines. Each object in the array becomes one logfmt line.

Flags:
  -h, -help    show help

Examples:
  echo '[{"key":"value"}]' | json-to-logfmt
  json-to-logfmt < data.json
  cat logs.json | json-to-logfmt
`, version)
}
