#!/bin/bash

#SBATCH -A iPlant-Collabs
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 02:00:00
#SBATCH -p development
#SBATCH -J ohmash
#SBATCH -o ohmash-%j.out
#SBATCH --mail-type BEGIN,END,FAIL
#SBATCH --mail-user kyclark@email.arizona.edu

run.sh -q "$WORK/pov/fasta" -o "$WORK/pov/mash"
