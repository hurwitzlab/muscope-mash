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
BINTAR="bin.tgz"
if [[ -e $BINTAR ]]; then
  tar xvf $BINTAR
  PATH="$CWD/bin:$PATH"
fi

QUERY_FILES=$(mktemp)
if [[ -d $QUERY  ]]; then
  find $QUERY -type f > $QUERY_FILES
else
  echo $QUERY > $QUERY_FILES
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
REF_MASH_DIR="$WORK/ohana/mash"
REF_SKETCH_DIR="$REF_MASH_DIR/sketches"

if [[ ! -d $REF_SKETCH_DIR ]]; then
  echo REF_SKETCH_DIR \"$REF_SKETCH_DIR\" does not exist.
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
  echo Sketching NUM_FILES \"$NUM_FILES\"
  while read FILE; do
    SKETCH_FILE="$QUERY_SKETCH_DIR/$(basename $FILE)"
    if [[ -e "${SKETCH_FILE}.msh" ]]; then
      echo SKETCH_FILE \"$SKETCH_FILE.msh\" exists already.
    else
      mash sketch -p $NUM_THREADS -o "$SKETCH_FILE" "$FILE"
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

ALL_FILES="${OUT_DIR}/all-files.txt"
find "$QUERY_SKETCH_DIR" -name \*.msh > "$ALL_FILES"
find "$REF_SKETCH_DIR" -name \*.msh  >> "$ALL_FILES"

if [[ -e "$ALL_FILES" ]]; then
  echo "Created ALL_FILES \"$ALL_FILES\""
fi

ALL_MASH="${OUT_DIR}/all"

if [[ -e "$ALL_MASH.msh" ]]; then
  rm "$ALL_MASH.msh"
fi

mash paste -l $ALL_MASH $ALL_FILES

ALL_MASH="$ALL_MASH.msh"

if [[ -e "$ALL_MASH" ]]; then
  echo "Created ALL_MASH \"$ALL_MASH\""
fi

DISTANCE_MATRIX="${OUT_DIR}/mash-dist.txt"
mash dist -t "$ALL_MASH" "$ALL_MASH" > "$DISTANCE_MATRIX"

if [[ -e "$DISTANCE_MATRIX" ]]; then
  echo "Created DISTANCE_MATRIX \"${DISTANCE_MATRIX}\""
fi

echo "Fixing dist output"
FIXED_DIST="$OUT_DIR/distance.txt"

process-dist.pl6 --in="$DISTANCE_MATRIX" --out="$FIXED_DIST"

if [[ -e "$FIXED_DIST" ]]; then
  echo "Created FIXED_DIST \"$FIXED_DIST\""
  sna.r -f "$FIXED_DIST" -o "$OUT_DIR" -n "$NUM_SCANS"

  for FILE in gbme.out Z table1.tex; do
    TMP="$OUT_DIR/$FILE"
    if [[ -e "$TMP" ]]; then
      rm $TMP
    fi
  done

  SNA="$OUT_DIR/sna-gbme.pdf"
  if [[ -e "$SNA" ]]; then
    echo "Finished SNA, see \"$SNA\""
  else
    echo "Something went wrong."
  fi
fi

echo "Comments to kyclark@email.arizona.edu"
