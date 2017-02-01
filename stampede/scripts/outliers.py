#!/usr/bin/env python

# Authors: 
# Joshua Lynch     <jklynch.arizona.edu>
# Ken Youens-Clark <kyclark@email.arizona.edu>

import argparse
import os
import matplotlib.pyplot as plt 
import pandas as pd

def main():
    args     = get_args()
    dist     = args.distance
    out_file = args.out_file
    num_sd   = args.sd

    if num_sd <= 0:
        print('--sd must be a postive value')
        exit(1)

    if not os.path.isfile(dist):
        print('--distance "{}" is not a file'.format(dist))
        exit(1)

    out_dir = os.path.dirname(out_file)
    if not os.path.isdir(out_dir):
        mkdir(out_dir)

    df = pd.read_table(filepath_or_buffer=dist, index_col=0)
    row_means = df.mean()
    row_means.index = range(row_means.shape[0])
    mn = row_means.mean()
    sd = row_means.std()
    outliers = row_means[row_means > (mn + (sd * num_sd))]
    if len(outliers) > 0:
        print('\n'.join(
            ['OUTLIERS: '] +
            map(lambda i: '{} ({:.2f})'.format(
                df.index[i], outliers[i]), outliers.index)))
    else:
        print('No outliers')

    keep = row_means[row_means <= (mn + sd)]
    if len(keep) > 0:
        with open(out_file, 'wt') as fh:
            fh.write('\n'.join(df.index[keep.index]))
    else:
        print('All values fall outside {} SD'.format(num_sd))

def get_args():
    parser = argparse.ArgumentParser(description='Remove outliers from Mash distance matrix')
    parser.add_argument('-d', '--distance', help='Distance matrix',
        type=str, metavar='FILE', required=True)
    parser.add_argument('-o', '--out_file', help='Output filename',
        type=str, metavar='FILE', required=True)
    parser.add_argument('-s', '--sd', help='Number of standard deviations (1)',
        type=float, metavar='NUM', default=1)
    return parser.parse_args()

if __name__ == '__main__':
    main()
