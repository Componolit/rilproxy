#!/usr/bin/python3

import sys
import re

tables = { 'REQUEST': {}, 'RESPONSE': {}, 'UNSOL': {}, 'ERROR': {}}

with open (sys.argv[1], 'r') as r:
    for line in r:

        # REQUEST/RESPONSE/UNSOL
        match = re.match ('#define\s+RIL_(REQUEST|RESPONSE|UNSOL)_([^ ]+)\s+(.*)', line)
        if match:
            prefix = match.group(1) 
            name   = match.group(2) 
            value  = int(match.group(3))

            # Ignore base value for responses
            if prefix + "_" + name == "UNSOL_RESPONSE_BASE": continue

            try:
                tables[prefix][name] = value
            except KeyError:
                print ("Invalid prefix: '%s'" % prefix)
                sys.exit(1)

        # Error codes
        match = re.match ('\s+RIL_E_([^ ]+)\s*=\s*([^, ]+),', line)
        if match:
            tables['ERROR'][match.group(1)] = int(match.group(2))

# rilproxy specific request codes
tables['REQUEST']['SETUP'] = 0xc715
tables['REQUEST']['TEARDOWN'] = 0xc717

for table in tables:
    print ("\n-- %s" % (table))

    # Write constants
    for name in sorted(tables[table], key=lambda x: tables[table][x]):
        print("%s_%s = 0x%4.4x" % (table, name, tables[table][name]))

    # Write table for mapping strings to constants
    print ("%s = {" % (table), end='')
    for i, name in enumerate(sorted(tables[table], key=lambda x: tables[table][x])):
        separator = "," if i > 0 else ""
        print('%s\n    [%s_%s] = "%s"' % (separator, table, name, name), end='')
    print ("\n}")
