#!/bin/bash

: '
This template aligns reads to the index after trimming the 
read to be the same length as tiles in the library.
For more on bowtie alignment, see the options
documented by bowtie.

We report only the best alignment found, and no more.

You may specify the number of allowed mismatches in the config file
or hard-code it (or any other options) here.
'

set -euo pipefail

FASTQ="!{read1}"
INDEX=!{index}/peptide
ALIGN_OUT_FN=!{sample_id}.sam
CPUS=!{task.cpus}

if [[ !{params.paired_end} == true ]]; then
    BOWTIE2_ARGS=( !{params.bowtie2_optional_args} )
    bowtie2 "${BOWTIE2_ARGS[@]}" \
        --no-mixed --no-discordant \
        -p "$CPUS" -x "$INDEX" \
        -1 "$FASTQ" -2 "!{read2}" \
        -S "$ALIGN_OUT_FN"
    exit 0
fi

STREAM_FILE_CMD=!{params.fastq_stream_func}
READ_LENGTH=!{params.read_length}
PEPTIDE_LENGTH=!{params.oligo_tile_length}
MM=!{params.n_mismatches}
OP_ARGS="!{params.bowtie_optional_args}"

if [ ${PEPTIDE_LENGTH} -lt ${READ_LENGTH} ]; then
    let TRIM3=${READ_LENGTH}-${PEPTIDE_LENGTH}
else
    TRIM3=0
fi

echo $OP_ARGS

$STREAM_FILE_CMD "$FASTQ" | bowtie \
  --trim3 $TRIM3 \
  --threads $CPUS \
  -n $MM \
  -l $PEPTIDE_LENGTH \
  $OP_ARGS \
  -x $INDEX - > $ALIGN_OUT_FN
