#!/bin/bash

#SBATCH -A iPlant-Collabs
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 02:00:00
#SBATCH -p development
#SBATCH -J ohmash
#SBATCH -o ohmash-%j.out
#SBATCH --mail-type BEGIN,END,FAIL
#SBATCH --mail-user jklynch@email.arizona.edu

OUT_DIR="$SCRATCH/data/gos/muscope-mash/gos"

mkdir -p ${OUT_DIR}

if [[ -d $OUT_DIR ]]; then
  rm -rf $OUT_DIR
fi

run.sh -q "$WORK/cyverse-apps/test-data/gos/samples/*/*.fa.gz" -o $OUT_DIR
