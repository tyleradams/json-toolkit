package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/go-logfmt/logfmt"
)

const version = "3.0.1"

func main() {
	helpFlag := flag.Bool("help", false, "show help")
	hFlag := flag.Bool("h", false, "show help")
	flag.Parse()

	if *helpFlag || *hFlag {
		showHelp()
		os.Exit(0)
	}

	// Read logfmt lines from stdin and convert to JSON array
	scanner := bufio.NewScanner(os.Stdin)
	var result []map[string]interface{}

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		// Parse the logfmt line
		decoder := logfmt.NewDecoder(strings.NewReader(line))
		record := make(map[string]interface{})

		for decoder.ScanRecord() {
			for decoder.ScanKeyval() {
				key := string(decoder.Key())
				value := string(decoder.Value())
				record[key] = value
			}
		}

		if err := decoder.Err(); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing logfmt: %v\n", err)
			os.Exit(1)
		}

		result = append(result, record)
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "Error reading input: %v\n", err)
		os.Exit(1)
	}

	// Output as JSON
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(result); err != nil {
		fmt.Fprintf(os.Stderr, "Error encoding JSON: %v\n", err)
		os.Exit(1)
	}
}

func showHelp() {
	fmt.Printf(`logfmt-to-json - convert logfmt format to JSON (version %s)

Usage:
  logfmt-to-json [flags]

Overview:
  logfmt-to-json reads logfmt-formatted lines from standard input and outputs
  a JSON array. Each logfmt line is parsed into a JSON object.

Flags:
  -h, -help    show help

Examples:
  echo "key=value foo=bar" | logfmt-to-json
  logfmt-to-json < logs.txt
  cat access.log | logfmt-to-json | jq '.'
`, version)
}
