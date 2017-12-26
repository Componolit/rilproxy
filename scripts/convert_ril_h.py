#!/usr/bin/env python3 
import sys
import re
import argparse
from pyparsing import *

# Tables defining prefices to be trimmed from enum table entries
trim_prefixes = {
    'ERRNO':                        'RIL_E',
    'CALLSTATE':                    'RIL_CALL',
    'RADIOSTATE':                   'RADIO_STATE',
    'RADIOTECHNOLOGY':              'RADIO_TECH',
    'RADIOACCESSFAMILY':            'RAF',
    'RADIOBANDMODE':                'BAND_MODE',
    'RADIOCAPABILITYPHASE':         'RC_PHASE',
    'RADIOCAPABILITYSTATUS':        'RC_STATUS',
    'PREFERREDNETWORKTYPE':         'PREF_NET_TYPE',
    'CDMASUBSCRIPTIONSOURCE':       'CDMA_SUBSCRIPTION_SOURCE',
    'UUS_TYPE':                     'RIL_UUS',
    'USS_DCS':                      'RIL_UUS_DCS',
    'RADIOTECHNOLOGYFAMILY':        'RADIO_TECH',
    'CARRIERMATCHTYPE':             'RIL_MATCH',
    'LASTCALLFAILCAUSE':            'CALL_FAIL',
    'DATACALLFAILCAUSE':            'PDP_FAIL',
    'DATAPROFILE':                  'RIL_DATA_PROFILE',
    'CARDSTATE':                    'RIL_CARDSTATE',
    'PERSOSUBSTATE':                'RIL_PERSOSUBSTATE',
    'APPSTATE':                     'RIL_APPSTATE',
    'PINSTATE':                     'RIL_PINSTATE',
    'APPTYPE':                      'RIL_APPTYPE',
    'REGSTATE':                     'RIL',
    'SIMREFRESHRESULT':             'SIM',
    'CDMA_OTA_PROVISIONSTATUS':     'CDMA_OTA_PROVISION_STATUS',
    'CELLINFOTYPE':                 'RIL_CELL_INFO_TYPE',
    'TIMESTAMPTYPE':                'RIL_TIMESTAMP_TYPE',
    'CDMA_INFORECNAME':             'RIL_CDMA',
    'CDMA_REDIRECTINGREASON':       'RIL_REDIRECTING_REASON',
    'HARDWARECONFIG_TYPE':          'RIL_HARDWARE_CONFIG',
    'HARDWARECONFIG_STATE':         'RIL_HARDWARE_CONFIG',
    'SSSERVICETYPE':                'SS',
    'SSREQUESTTYPE':                'SS',
    'SSTELESERVICETYPE':            'SS',
    'DCPOWERSTATES':                'RIL_DC_POWER_STATE',
    'APNTYPES':                     'RIL_APN_TYPE',
    'DEVICESTATETYPE':              'RIL_DST',
    'UNSOLICITEDRESPONSEFILTER':    'RIL_UR',
    'SCANTYPE':                     'RIL',
    'GERANBANDS':                   'GERAN_BAND',
    'UTRANBANDS':                   'UTRAN_BAND',
    'EUTRANBANDS':                  'EUTRAN_BAND',
    'KEEPALIVESTATUSCODE':          'KEEPALIVE',
    'REQUEST':                      'REQUEST',
    'RESPONSE':                     'RESPONSE',
    'UNSOL':                        'UNSOL',
    'RESTRICTED_STATE':             'RESTRICTED_STATE'
}

# Defines to generate tables for
generate_defines = ['REQUEST', 'RESPONSE', 'UNSOL', 'RESTRICTED_STATE']

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

def parse_positive(s, loc, toks):
    return int(toks[0], 10)

def parse_negative(s, loc, toks):
    return -toks[0]

def parse_hexdecimal(s, loc, toks):
    return int(toks[0], 0)

def parse_enum(s, loc, toks):
    result = {}
    none_vals = 0

    # an enum must only have implicit values at the end
    for (key, value) in toks[0]:
        if value is None:
            none_vals += 1
        else:
            if none_vals: raise Exception("Enum %s has explicit and implicit values (%s=%s, none_vals=%d)" % (toks[1], key, str(value), none_vals))

    prev = -1
    for (key, value) in toks[0]:
        if not value:
            value = prev + 1
        else:
            prev = value

        result[value] = key

    return (toks[1], result)

def parse_bitshift(s, loc, toks):
    return (1 << int(defines[toks[0]]))

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
    
    terminator  = Literal(";")
    equal       = Literal("=")
    
    name        = Word(alphanums + "_")

    positive    = Regex("\d+")
    positive.setParseAction(parse_positive)

    negative    = Suppress(Literal("-")) + positive
    negative.setParseAction(parse_negative)

    hexadecimal = Combine (Literal("0x") + Regex("[0-9a-fA-F]+"))
    hexadecimal.setParseAction(parse_hexdecimal)

    bitshift    = Suppress(Literal("(")) + Suppress(Literal("1")) + Suppress(Literal("<<")) + name + Suppress(Literal(")"))
    bitshift.setParseAction(parse_bitshift)

    define = Word(alphanums + "_")
    define.setParseAction(parse_define)

    value  = (hexadecimal|negative|positive|bitshift|define)
    
    typename    = name
    enumspec    = typename + Optional(Suppress(equal) + value)
    enumspec.setParseAction(parse_enumspec)
    
    enumdef     = Suppress(kw_typedef) + Suppress(kw_enum) + Suppress(Literal("{")) + Group(delimitedList(enumspec)) + \
        Suppress(Optional(",")) + Suppress(Literal("}")) + typename + Suppress(terminator)
    enumdef.setParseAction(parse_enum)
    
    enums = OneOrMore(enumdef) + StringEnd()

    result = enums.parseString(content)
    return result

def trim_prefix(value, prefix):
    if value.startswith(prefix):
        return value[len(prefix):]
    return value

def output_lua_table(fh, tablename, data):

    fh.write ("-- %s\n" % (tablename))

    if tablename in trim_prefixes:
        prefix = trim_prefixes[tablename]
    else:
        prefix = ''

    # Write constants
    for key in sorted(data):
        entryname = trim_prefix(data[key], prefix + '_')
        # Use decimal for negative numbers
        fmt = "%d" if key < 0 else "0x%4.4x"
        fh.write(("%s_%s = " + fmt + "\n") % (tablename, entryname, key))

    # Write table for mapping strings to constants
    fh.write("%s = {" % (tablename))
    for i, key in enumerate(sorted(data)):
        separator = "," if i > 0 else ""
        entryname = trim_prefix(data[key], prefix + '_')
        fh.write('%s\n    [%s_%s] = "%s"' % (separator, tablename, entryname, entryname))
    fh.write("\n}\n")

def output_lua(result, filename):

    with open(filename, 'w') as f:

        f.write("RIL_VERSION = %s\n" % (defines['RIL_VERSION']))

        # Output all enums
        for (name, data) in result:
            name = trim_prefix(name, 'RIL_')
            if name in ignore_enums:
                continue
            output_lua_table(f, name.upper(), data)

        for tablename in generate_defines:
            table = {}
            for define in defines:
                name = trim_prefix(define, 'RIL_')
                if name.startswith(tablename + '_'):
                    table[int(defines[define], 0)] = name
            output_lua_table(f, tablename, table)

def main():

    parser = argparse.ArgumentParser(description='Parse ril.h file.')
    parser.add_argument('--output', action='store', required=True, help='Output file name')
    parser.add_argument('ril_h', action='store', help='ril.h file to analyze')
    args = parser.parse_args()

    data = parse_ril(args.ril_h)
    output_lua(data, args.output)

if __name__ == '__main__':
    main()
