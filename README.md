# JSON Toolkit

Fast, composable command-line utilities for converting, querying, validating, and transforming JSON and related data formats.

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](LICENSE)

## Overview

JSON Toolkit is a comprehensive suite of command-line utilities designed to make it easy to work with JSON and other data formats. Whether you need to convert data, manipulate it, or extract information, this toolkit has you covered.

### Features

- **Format conversion**: Bidirectional conversion between JSON and CSV, XML, YAML, TOML, HTML, logfmt, environment variables, and more
- **JSON manipulation**: Format, diff, schema generation, and data transformation
- **Database integration**: Read from and write to PostgreSQL, MySQL, SQLite3, and Oracle Autonomous Database
- **Unix-friendly**: All tools follow Unix philosophy—read from stdin, write to stdout, composable with pipes
- **Lightweight**: Simple utilities with minimal dependencies, designed for scripting and automation

## Installation

### Via APT (Debian/Ubuntu)

```bash
sudo add-apt-repository ppa:code-faster/ppa
sudo apt update
sudo apt install json-toolkit
```

### Build from Source

#### Prerequisites

- Bash
- Go (golang-go)
- Python 3
- [jq](https://stedolan.github.io/jq/) (>= 1.5)

#### Build Steps

```bash
git clone https://github.com/tyleradams/json-toolkit.git
cd json-toolkit
make
make test
sudo make install
```

## Quick Start

```bash
# Convert CSV to JSON
csv-to-json < data.csv > data.json

# Pretty-print JSON
json-format < data.json

# Compare two JSON files
json-diff file1.json file2.json

# Query PostgreSQL and output as JSON
json-sql read psql user password localhost 5432 mydb

# Convert JSON to YAML
json-to-yaml < config.json > config.yaml

# Generate JSON schema from sample data
json-make-schema < sample.json > schema.json
```

## Usage

All utilities follow the same pattern:
- Read from stdin (or files where specified)
- Write to stdout
- Return exit code 0 on success, non-zero on failure
- Provide `--help` or `-h` for detailed usage

### Format Conversion Tools

#### To JSON

- `csv-to-json` - Convert CSV to JSON array
- `dsv-to-json` - Convert delimiter-separated values to JSON
- `xml-to-json` - Convert XML to JSON
- `yaml-to-json` - Convert YAML to JSON
- `toml-to-json` - Convert TOML to JSON
- `html-to-json` - Convert HTML to JSON
- `logfmt-to-json` - Convert logfmt to JSON
- `env-to-json` - Convert environment variables to JSON
- `diff-to-json` - Convert unidiff patches to JSON
- `binary-to-json` - Convert binary data to JSON
- `python-to-json-ast` - Parse Python code to JSON AST

#### From JSON

- `json-to-csv` - Convert JSON to CSV
- `json-to-dsv` - Convert JSON to delimiter-separated values
- `json-to-xml` - Convert JSON to XML
- `json-to-yaml` - Convert JSON to YAML
- `json-to-env` - Convert JSON to environment variable format
- `json-to-logfmt` - Convert JSON to logfmt
- `json-to-binary` - Convert JSON to binary

### JSON Manipulation Tools

- `json-format` - Pretty-print or minify JSON
- `json-diff` - Compare two JSON files and output structured differences
- `json-make-schema` - Generate JSON schema from input data
- `json-table-to-objs` - Convert JSON table format to objects
- `json-objs-to-table` - Convert JSON objects to table format

### Database Tools

- `json-sql` - Read from or write to SQL databases (PostgreSQL, MySQL, SQLite3, Oracle ADB)

```bash
# Read entire database as JSON
json-sql read psql user password localhost 5432 database

# Execute queries from JSON array
echo '["SELECT * FROM users WHERE id = 1"]' | json-sql query psql user password localhost 5432 database

# SQLite example
json-sql read sqlite3 mydata.db

# MySQL example
json-sql read mysql user password localhost 3306 database
```

### Other Tools

- `json-run` - Execute code based on JSON input
- `pjito` - "Python JSON in, text out" - template renderer
- `json-to-plot` - Generate plots from JSON data

## Examples

### Convert and transform data

```bash
# CSV to JSON, filter with jq, convert to YAML
csv-to-json < users.csv | jq '.[] | select(.active == true)' | json-to-yaml > active-users.yaml

# Read PostgreSQL table, extract specific fields
json-sql read psql user pass localhost 5432 db | jq '.users[] | {id, email}' > user-emails.json

# Compare two configuration files
json-diff config-old.json config-new.json | json-format
```

### Database operations

```bash
# Dump entire database to JSON
json-sql read psql postgres password localhost 5432 mydb > backup.json

# Insert data from JSON
echo '["INSERT INTO logs (message, level) VALUES ('"'"'test'"'"', '"'"'info'"'"')"]' | \
  json-sql query sqlite3 app.db
```

### Schema generation and validation

```bash
# Generate schema from sample data
json-make-schema < sample-data.json > schema.json

# Use the schema for documentation or validation
```

## Exit Codes

All utilities follow standard exit code conventions:
- `0` - Success
- `1` - Runtime or I/O error (file not found, parse error, etc.)
- `2` - Usage error (invalid arguments or options)

Some utilities have specialized exit codes (see individual `--help` for details).

## Development

### Build

```bash
make           # Build all components
make clean     # Remove build artifacts
```

### Test

```bash
make test      # Run all tests
./run-json-diff-tests      # Test json-diff specifically
./run-all-tests            # Complete test suite
```

### Code Quality

```bash
make fmt       # Format code (Go and Python)
make lint      # Run linters
```

### Install Locally

```bash
make install                    # Install to /usr/local/bin (requires sudo)
make prefix=/custom/path install # Install to custom location
```

## Project Structure

```
json-toolkit/
├── src/              # Source files for all utilities
│   ├── *.go         # Go programs (json-diff)
│   ├── *-to-json    # Python conversion utilities
│   ├── json-to-*    # Python output converters
│   └── json-*       # JSON manipulation tools
├── test_data/       # Test fixtures and expected results
├── debian/          # Debian packaging files
├── Makefile         # Root build configuration
└── README.md        # This file
```

## Dependencies

### Runtime Dependencies

- Python 3
- jq (>= 1.5)
- Go (for json-diff)

### Python Libraries

The following Python packages are required (automatically installed with the Debian package):

- `psycopg2-binary` - PostgreSQL support
- `PyMySQL` - MySQL support
- `cx_Oracle` - Oracle Database support
- `PyYAML` - YAML format support
- `xmltodict` - XML format support
- `unidiff` - Diff format support
- `logfmt` - Logfmt format support
- `genson` - JSON schema generation
- `ast2json` - Python AST parsing

## Contributing

Contributions are welcome! Here's how to get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`make test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

Please ensure:
- All tests pass
- Code follows existing style (run `make fmt` and `make lint`)
- New utilities include help text and examples
- Documentation is updated

## Versioning

This project uses [Semantic Versioning](https://semver.org/). For available versions, see the [releases page](https://github.com/tyleradams/json-toolkit/releases).

## License

This project is licensed under the GNU General Public License v2.0 - see the [LICENSE](LICENSE) file for details.

## Feedback and Support

- **Issues**: Report bugs or request features on our [GitHub Issues](https://github.com/tyleradams/json-toolkit/issues) page
- **Questions**: For usage questions, please open a discussion or issue

## Acknowledgements

Special thanks to:
- The jq project for inspiration on composable JSON tools
- All contributors and users who have provided feedback
- The open-source community for the excellent libraries this project builds upon

---

*"the best opensource converter I've found across the Internet"* - dene14
