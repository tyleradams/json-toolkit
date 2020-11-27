#!/usr/bin/env python3

import json
import sys
import xmltodict


def main():
    if len(sys.argv) != 1:
        print("Usage: xml-to-json")

    xml_string = sys.stdin.read()
    data = xmltodict.parse(xml_string)
    print(json.dumps(data))


if __name__ == "__main__":
    main()
