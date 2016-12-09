#!/bin/bash

set -u

QUERY=""
OUT_DIR=$(pwd)

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
  echo ""
  exit 0
}

if [[ $# -eq 0 ]]; then
  HELP
fi

while getopts :o:q:h OPT; do
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
    :)
      echo "Error: Option -$OPTARG requires an argument."
      exit 1
      ;;
    \?)
      echo "Error: Invalid option: -${OPTARG:-""}"
      exit 1
  esac
done

BINTAR="bin.tgz"
if [[ -e $BINTAR ]]; then
  tar xvf $BINTAR
  PATH="./bin:$PATH"
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
MASH="$WORK/bin/mash"

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
      $MASH sketch -o "$SKETCH_FILE" "$FILE"
    fi
  done < $QUERY_FILES

  echo Making ALL_QUERY \"$ALL_QUERY\" 

  QUERY_SKETCHES=$(mktemp)
  find "$QUERY_SKETCH_DIR" -name \*.msh > "$QUERY_SKETCHES"
  $MASH paste -l "$ALL_QUERY" "$QUERY_SKETCHES"

  rm "$QUERY_FILES"
  rm "$QUERY_SKETCHES"
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

  echo "Pasting \"$NUM_MASH\" files to ALL_REF \"$ALL_REF\""
  $MASH paste -l "$ALL_REF" "$MSH_FILES"
  rm "$MSH_FILES"
fi
ALL_REF=${ALL_REF}.msh

echo "DIST $(basename $ALL_QUERY) $(basename $ALL_REF)"
DISTANCE_MATRIX="${OUT_DIR}/mash-dist.txt"
echo "DISTANCE_MATRIX \"${DISTANCE_MATRIX}\""
$MASH dist -t "$ALL_QUERY" "$ALL_REF" > "$DISTANCE_MATRIX"
rm "$ALL_QUERY"

echo "Fixing dist output"

process-dist.pl6 --in="$DISTANCE_MATRIX" --out="$OUT_DIR/distance.txt"

echo "Done."
