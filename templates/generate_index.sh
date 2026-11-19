#!/bin/bash

set -euo pipefail

FASTA=!{oligo_fasta}
CPUS=!{task.cpus}

mkdir -p peptide_index
INDEX_BUILDER=bowtie-build
if [[ !{params.paired_end} == true ]]; then
    INDEX_BUILDER=bowtie2-build
fi

"$INDEX_BUILDER" \
    --threads "$CPUS" \
    "$FASTA" \
    peptide_index/peptide
