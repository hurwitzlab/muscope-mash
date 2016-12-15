#!/usr/bin/env python3

import argparse
import re
from pathlib import Path
from itertools import chain

def main():
    args    = get_args()
    aliases = get_aliases(args.alias)
    outfile = args.out

    if outfile is None:
        f        = Path(args.input.name)
        basename = f.name
        dirname  = f.parents[0]
        ext      = f.suffix
        outfile  = Path(dirname, re.sub(ext + r'$', '.2' + ext, basename))

    def clean_file_name(f):
        name = Path(f).name
        name = re.sub(r'\.msh$', '', name)
        name = re.sub(r'\.gz$', '', name)
        name = re.sub(r'\.fn?a(st[aq])?$', '', name)
        if name in aliases:
            name = aliases[name]
        return name

    for i, line in enumerate(args.input):
        flds = line.rstrip("\n").split("\t")
        if i == 0:
            flds = flds[1:] # remove "#query"
            outfile.write("\t".join(chain([""], map(clean_file_name, flds))) + "\n")
        else:
            filename = flds[0]
            vals     = flds[1:]

            if args.nearness == True:
                vals = map(lambda x: str(1 - float(x)), vals)

            # I have to put the filename into a list otherwise chain
            # breaks it into characters
            outfile.write("\t".join(chain([clean_file_name(filename)], vals)) + "\n")

    print("Done, see ", outfile.name)

def get_aliases(alias_file):
    aliases = dict()
    if alias_file is not None:
        aliases = dict( [ line.strip().split('\t') for line in alias_file ] )
    return aliases

def get_args():
    parser = argparse.ArgumentParser(description='Process output from Mash')
    parser.add_argument('-i', '--input', metavar='FILE',
            type=argparse.FileType('r'), help='input file', required=True)
    parser.add_argument('-o', '--out', metavar='FILE',
            type=argparse.FileType('w'), help='output file')
    parser.add_argument('-a', '--alias', metavar='FILE', 
            type=argparse.FileType('r'), help='alias file')
    parser.add_argument('-n', '--nearness', help='invert distance',
            action="store_true", default=False)
    return parser.parse_args()

if __name__ == '__main__':
    main()
