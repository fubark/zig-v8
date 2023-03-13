#!/usr/bin/env python

# Parses DEPS file and outputs json.
# The DEPS file is just python code so we capture the vars in exec and convert to json.

import sys
import json

def Var(arg):
    return '@' + arg

def main():
    deps_file = open(sys.argv[1], "r")
    deps_str = deps_file.read()
    deps_file.close()

    out = {}
    exec(deps_str, globals(), out)
    print(json.dumps(out))

if __name__ == "__main__":
    main()