#!/bin/bash

set -euo pipefail
CPUS=!{task.cpus}

# Convert SAM to BAM, and sort
VIEW_FLAGS=()
if [[ !{params.paired_end} == true ]]; then
    # Keep primary, properly paired R1 records with both reads mapped.
    VIEW_FLAGS=(-f 0x43 -F 0x90C)
fi
samtools view -u -@ ${CPUS} "${VIEW_FLAGS[@]}" !{sam_file} | \
    samtools sort -@ ${CPUS} - > !{sample_id}.bam

# Sort the BAM again
samtools sort -@ ${CPUS} !{sample_id}.bam -o !{sample_id}.sorted 

# Overwrite the first sorted BAM with the second
mv !{sample_id}.sorted !{sample_id}.bam

# Index the BAM
samtools index -b !{sample_id}.bam

# Count mapped reads (single-end) or fragments (paired-end) per reference.
samtools idxstats !{sample_id}.bam | \
    cut -f 1,3 | \
    awk -F '\t' '$1 != "*"' > !{sample_id}.counts
