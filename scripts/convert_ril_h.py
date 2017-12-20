#!/usr/bin/env python3 
import sys
import re
import argparse
from pyparsing import *

# Ignore enums in this list
ignore_enums = ['SOCKET_ID']

# Pre-init with external constants used in ril.h
defines = {'INT32_MAX': 0xffffffff}

def parse_enumspec(s, loc, toks):
    if len(toks) < 2:
        value = None
    else:
        value = toks[1]

    # Put enum value into global defines table
    defines[toks[0]] = value
    return (toks[0], value)

def parse_define(s, loc, toks):
    return defines[toks[0]]

def parse_enum(s, loc, toks):
    result = {}
    none_vals = 0

    # an enum must only have implicit values at the end
    for (key, value) in toks[0]:
        if not value:
            none_vals += 1
        else:
            if none_vals: raise Exception("Enum %s has explicit and implicit values" % toks[1])

    i = 0
    for (key, value) in toks[0]:
        if none_vals and value:
            i = int(value) + 1
        else:
            value = i
            i += 1
        result[int(value)] = key

    return (toks[1], result)

def parse_bitshift(s, loc, toks):
    return defines[toks[0]]

def parse_ril(filename):

    with open(filename, 'r') as f:
        content = "".join(f.readlines())

    definelist= re.findall('^#define\s+([^ ]+)\s+(.*)$', content, flags=re.MULTILINE)
    for (name, value) in definelist:
        defines[name] = value

    # remove comments and other clutter
    content = re.sub('\/\*.*?\*\/', '', content, flags=re.MULTILINE|re.DOTALL)
    content = re.sub('\s*\/\/.*', '', content)
    content = re.sub('#(if|endif).*', '', content)
    content = re.sub('union\s*{[^}]*?}\s*[^;]*;', '', content, flags=re.MULTILINE|re.DOTALL)
    content = re.sub('typedef\s+struct\s+{\s+[^}]*\s+}[^;]+;', '', content, flags=re.MULTILINE|re.DOTALL)
    
    content = "\n".join(re.findall('typedef\s+enum\s+{\s*.+?\s*}\s*[^;]+\s*;', content, flags=re.MULTILINE|re.DOTALL))

    kw_enum     = Literal("enum")
    kw_typedef  = Literal("typedef")
    
    name        = Word(alphanums + "_")
    
    decimal     = Regex("\d+")
    hexadecimal = Combine (Literal("0x") + Regex("[0-9a-fA-F]+"))
    number      = hexadecimal|(Optional(Literal("-")) + decimal)
    terminator  = Literal(";")
    equal       = Literal("=")
    
    bitshift    = Suppress(Literal("(")) + Suppress(Literal("1")) + Suppress(Literal("<<")) + name + Suppress(Literal(")"))
    bitshift.setParseAction(parse_bitshift)

    define = Word(alphanums + "_")
    define.setParseAction(parse_define)

    value  = (number|bitshift|define)
    
    typename    = name
    enumspec    = typename + Optional(Suppress(equal) + value)
    enumspec.setParseAction(parse_enumspec)
    
    enumdef     = Suppress(kw_typedef) + Suppress(kw_enum) + Suppress(Literal("{")) + Group(delimitedList(enumspec)) + \
        Suppress(Optional(",")) + Suppress(Literal("}")) + typename + Suppress(terminator)
    enumdef.setParseAction(parse_enum)
    
    enums = OneOrMore(enumdef) + StringEnd()

    result = enums.parseString(content)
    return result

def output_lua_table(tablename, data):

    print ("\n-- %s" % (tablename))

    # Write constants
    for key in data:
        print("%s_%s = 0x%4.4x" % (tablename, data[key], key))

    # Write table for mapping strings to constants
    print ("%s = {" % (tablename), end='')
    for i, key in enumerate(sorted(data)):
        separator = "," if i > 0 else ""
        print('%s\n    [%s_%s] = "%s"' % (separator, tablename, data[key], data[key]), end='')
    print ("\n}")

def output_lua(result, filename):

    #with open(filename, 'rw') as f:
    for (name, data) in result:
        if name.startswith('RIL_'):
            name = name[4:]
        if name in ignore_enums:
            continue
        output_lua_table(name.upper(), data)

def main():

    parser = argparse.ArgumentParser(description='Parse ril.h file.')
    parser.add_argument('--output', action='store', help='Output file name')
    parser.add_argument('ril_h', action='store', help='ril.h file to analyze')
    args = parser.parse_args()

    data = parse_ril(args.ril_h)
    output_lua(data, args.output)

if __name__ == '__main__':
    main()
