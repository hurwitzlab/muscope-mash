#!/bin/bash

set -u

if [[ $# -lt 4 ]]; then
  printf "Usage: %s REF_SKETCH_DIR QUERY_SKETCH_DIR OUT_DIR NUM_SCANS FILES_LIST\n" $(basename $0)
  exit 1
fi

REF_SKETCH_DIR=$1
QUERY_SKETCH_DIR=$2
OUT_DIR=$3
NUM_SCANS=$4
FILES_LIST=${5:-''}

#
# "all-files" will hold all the file names we want to compare
#
ALL_FILES="${OUT_DIR}/all-files.txt"

if [[ ! -d $REF_SKETCH_DIR ]]; then
  echo "REF_SKETCH_DIR \"$REF_SKETCH_DIR\" is not a directory"
  exit 1
fi

if [[ ! -d $QUERY_SKETCH_DIR ]]; then
  echo "QUERY_SKETCH_DIR \"$QUERY_SKETCH_DIR\" is not a directory"
  exit 1
fi

if [[ ${#FILES_LIST} -gt 0 ]] && [[ -f $FILES_LIST ]]; then
  while read FILE; do
    for DIR in $REF_SKETCH_DIR $QUERY_SKETCH_DIR; do
      SKETCH="$DIR/$(basename $FILE '.msh').msh"
      if [[ -e "$SKETCH" ]]; then
        echo "$SKETCH" >> $ALL_FILES
      fi
    done
  done < $FILES_LIST
else
  find "$REF_SKETCH_DIR"   -name \*.msh  > "$ALL_FILES"
  find "$QUERY_SKETCH_DIR" -name \*.msh >> "$ALL_FILES"
fi

if [[ -e "$ALL_FILES" ]]; then
  echo "Created ALL_FILES \"$ALL_FILES\""
fi

ALL_MASH="${OUT_DIR}/all"

if [[ -e "$ALL_MASH.msh" ]]; then
  rm "$ALL_MASH.msh"
fi

${WORK}/local/mash/mash paste -l $ALL_MASH $ALL_FILES

ALL_MASH="$ALL_MASH.msh"

if [[ -e "$ALL_MASH" ]]; then
  echo "Created ALL_MASH \"$ALL_MASH\""
fi

DISTANCE_MATRIX="${OUT_DIR}/mash-dist.txt"
${WORK}/mash/mash dist -t "$ALL_MASH" "$ALL_MASH" > "$DISTANCE_MATRIX"

if [[ -e "$DISTANCE_MATRIX" ]]; then
  echo "Created DISTANCE_MATRIX \"${DISTANCE_MATRIX}\""
fi

echo "Fixing dist output"
FIXED_DIST="$OUT_DIR/distance.txt"

process-dist.py --in="$DISTANCE_MATRIX" --out="$FIXED_DIST"

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
