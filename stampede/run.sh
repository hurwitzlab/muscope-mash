#!/bin/bash

set -u

QUERY=""
OUT_DIR=$(pwd)
NUM_THREADS=12
NUM_SCANS=10000

function lc() {
  wc -l "$1" | cut -d ' ' -f 1
}

function HELP() {
  printf "Usage:\n  %s -q QUERY -o OUT_DIR\n\n" $(basename $0)

  echo "Required arguments:"
  echo " -q QUERY (input FASTA file[s] or directory)"
  echo ""
  echo "Options:"
  echo " -o OUT_DIR ($OUT_DIR)"
  echo " -s NUM_SCANS ($NUM_SCANS)"
  echo " -t NUM_THREADS ($NUM_THREADS)"
  echo ""
  exit 0
}

if [[ $# -eq 0 ]]; then
  HELP
fi

while getopts :o:s:t:q:h OPT; do
  case $OPT in
    h)
      HELP
      ;;
    o)
      OUT_DIR="$OPTARG"
      ;;
    q)
      QUERY="$OPTARG"
      ;;
    s)
      NUM_SCANS="$OPTARG"
      ;;
    t)
      NUM_THREADS="$OPTARG"
      ;;
    :)
      echo "Error: Option -$OPTARG requires an argument."
      exit 1
      ;;
    \?)
      echo "Error: Invalid option: -${OPTARG:-""}"
      exit 1
  esac
done

CWD=$(cd $(dirname $0) && pwd)
SCRIPTS="$CWD/scripts.tgz"
if [[ -e $SCRIPTS ]]; then
  echo "Untarring $SCRIPTS to bin"
  if [[ ! -d bin ]]; then
    mkdir bin
  fi
  tar -C bin -xvf $SCRIPTS
fi

if [[ -e "$CWD/bin" ]]; then
  PATH="$CWD/bin:$PATH"
fi

#
# Mash sketching
#
QUERY_FILES=$(mktemp)
if [[ -d $QUERY  ]]; then
  find $QUERY -type f > $QUERY_FILES
else
  find $QUERY -type f > $QUERY_FILES
  #echo $QUERY > $QUERY_FILES
fi

NUM_FILES=$(lc "$QUERY_FILES")

if [[ $NUM_FILES -lt 1 ]]; then
  echo "No input files"
  exit 1
fi

if [[ ! -d $OUT_DIR ]]; then
  mkdir -p "$OUT_DIR"
fi

QUERY_SKETCH_DIR="$OUT_DIR/sketches"
KYC_WORK=/work/03137/kyclark
REF_MASH_DIR="$KYC_WORK/ohana/mash"
REF_SKETCH_DIR="$REF_MASH_DIR/sketches"

if [[ ! -d $REF_SKETCH_DIR ]]; then
  echo "REF_SKETCH_DIR \"$REF_SKETCH_DIR\" does not exist."
  exit 1
fi

if [[ ! -d $QUERY_SKETCH_DIR ]]; then
  mkdir -p "$QUERY_SKETCH_DIR"
fi

#
# Sketch the input files, if necessary
#
ALL_QUERY="$OUT_DIR/query-$$"
if [[ ! -s ${ALL_QUERY}.msh ]]; then
  echo "Sketching NUM_FILES \"$NUM_FILES\""
  while read FILE; do
    SKETCH_FILE="$QUERY_SKETCH_DIR/$(basename $FILE)"
    if [[ -e "${SKETCH_FILE}.msh" ]]; then
      echo "SKETCH_FILE \"$SKETCH_FILE.msh\" exists already."
    else
      ${WORK}/local/mash/mash sketch -p $NUM_THREADS -o "$SKETCH_FILE" "$FILE"
    fi
  done < $QUERY_FILES

  rm "$QUERY_FILES"
fi

ALL_QUERY=${ALL_QUERY}.msh

#
# The reference genomes ought to have been sketched already
#
ALL_REF="$REF_MASH_DIR/muscope"

if [[ ! -s "${ALL_REF}.msh" ]]; then
  MSH_FILES=$(mktemp)
  find "$REF_SKETCH_DIR" -type f -name \*.msh > $MSH_FILES
  NUM_MASH=$(lc "$MSH_FILES")

  if [[ $NUM_MASH -lt 1 ]]; then
    echo "Found no files in \"$REF_SKETCH_DIR\""
    exit 1
  fi

  rm "$MSH_FILES"
fi

#
# Run Mash on everything first
#
run-mash.sh "$REF_SKETCH_DIR" "$QUERY_SKETCH_DIR" "$OUT_DIR" "$NUM_SCANS" "$OUT_DIR"

#
# Check for outliers, run again if necessary
#
DIST="$OUT_DIR/distance.txt"

if [[ ! -f $DIST ]]; then
  echo "Cannot find distance file \"$DIST\""
  exit 1
fi

DIST_NO_OUTLIERS="$OUT_DIR/distance-no-outliers.txt"
echo "Checking for outliers"
RESULT=$(outliers.py -d "$DIST" -o "$DIST_NO_OUTLIERS")

echo $RESULT

if [[ $RESULT != "No outliers" ]] && [[ -s "$DIST_NO_OUTLIERS" ]]; then
  echo "Will re-run Mash now"

  mv "$OUT_DIR/sna-gbme.pdf" "$OUT_DIR/sna-gbme-with-outliers.pdf"

  run-mash.sh "$REF_SKETCH_DIR" "$QUERY_SKETCH_DIR" "$OUT_DIR" "$NUM_SCANS" "$DIST_NO_OUTLIERS"
fi

echo "Comments to kyclark@email.arizona.edu"
