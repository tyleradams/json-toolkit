# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JSON Toolkit is a comprehensive suite of command-line utilities for working with JSON and other data formats. The toolkit provides bidirectional converters between JSON and various formats (CSV, XML, YAML, TOML, HTML, logfmt, etc.), as well as utilities for JSON manipulation, schema generation, and database integration.

## Architecture

The project consists of three types of utilities:

1. **Python3 scripts**: Most converters and utilities (e.g., `csv-to-json`, `json-sql`, `json-make-schema`)
2. **Go programs**: Performance-critical utilities (`json-diff.go`)
3. **Bash scripts**: Simple wrappers and test utilities

All utilities follow a Unix philosophy:
- Read from stdin, write to stdout
- Exit code 0 for success, non-zero for failure
- JSON as the primary interchange format
- Composable with pipes and other Unix tools (especially `jq`)

## Build System

The project uses a two-level Makefile structure:
- Root `Makefile`: Orchestrates builds, tests, and packaging
- `src/Makefile`: Handles installation of individual utilities

### Common Commands

```bash
# Build everything (compiles Go programs and installs dependencies)
make

# Run all tests
make test

# Run individual test suites
./run-json-diff-tests        # Tests for json-diff
./run-all-tests               # Complete test suite

# Format code
make fmt

# Lint code
make lint
./run-bash-linter            # Bash-specific linting

# Install locally (to /usr/local/bin by default)
make install
sudo make install            # Usually requires sudo

# Clean build artifacts
make clean

# Build Go programs only
make json-diff
```

## Key Utilities

### Data Conversion
- **To JSON**: `csv-to-json`, `xml-to-json`, `yaml-to-json`, `toml-to-json`, `html-to-json`, `logfmt-to-json`, `env-to-json`, `diff-to-json`, `binary-to-json`, `dsv-to-json`
- **From JSON**: `json-to-csv`, `json-to-xml`, `json-to-yaml`, `json-to-env`, `json-to-logfmt`, `json-to-binary`, `json-to-dsv`

### JSON Manipulation
- `json-format`: Format/prettify JSON
- `json-diff`: Compare two JSON files and output structured differences (Go implementation)
- `json-make-schema`: Generate JSON schema from JSON data
- `json-table-to-objs`: Convert JSON table format to objects
- `json-objs-to-table`: Convert JSON objects to table format

### Database Integration
- `json-sql`: Read/write SQL databases (PostgreSQL, MySQL, SQLite3, Oracle ADB)
  - Supports both read (dump entire DB) and query (execute JSON array of queries)
  - See help: `./src/json-sql` (no args)

### Other Utilities
- `python-to-json-ast`: Parse Python code to JSON AST
- `pjito`: "Python JSON in, text out" - template renderer
- `json-run`: Execute code based on JSON input

## Testing Strategy

The test system uses `json-diff` to validate outputs:

1. `test_data/tests.json` contains test cases with expected results
2. `generate-test-results` runs tests and produces actual results
3. `json-diff` compares expected vs actual
4. `jq` checks if diff is empty (returns exit code 0 if no differences)

Test files in `test_data/`:
- `json-diff-tests.json`: Tests specifically for json-diff
- `tests.json`: General test suite
- Various `.json` files: Test fixtures (e.g., `a.json`, `b.json`, `m1.json`, `m2.json`)

## Dependencies

### System Dependencies
- Bash
- Go (golang-go)
- Python3
- jq (>= 1.5)
- libpq-dev (for PostgreSQL support)

### Python Dependencies
See `requirements.txt`. Install with:
```bash
python3 -m pip install -r requirements.txt
```

Key Python packages:
- Database drivers: `psycopg2-binary`, `PyMySQL`, `cx_Oracle`
- Format parsers: `PyYAML`, `xmltodict`, `unidiff`, `logfmt`
- Other: `genson` (schema generation), `ast2json` (Python AST parsing)

## Packaging and Distribution

The project is distributed as a Debian package via PPA:
```bash
sudo add-apt-repository ppa:code-faster/ppa
sudo apt update
sudo apt install json-toolkit
```

Build Debian package:
```bash
make package version=1.2.3
```

Publish to PPA (requires DEBSIGN_KEY):
```bash
make publish version=1.2.3 DEBSIGN_KEY=YOUR_KEY
```

## Code Style

- Python: Follow PEP8 (see `.pep8` and `.pylintrc` configs)
- Go: Use `go fmt` (automatically applied during build)
- Bash: Follow ShellCheck recommendations

## Development Notes

- Go programs are built to `target/` directory during packaging
- Most utilities are executable scripts in `src/` that can be run directly during development
- The `json-diff` utility is special: it's both a compiled Go binary and used extensively in testing, so changes require rebuild + test
- Python scripts have shebang `#!/usr/bin/env python3` for portability
