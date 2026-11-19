#!/bin/bash

set -euo pipefail

samtools stats !{sam_file} | \
    awk '/^SN\t(raw total sequences|reads mapped|error rate|average quality):\t/ { sub(/^SN\t/, ""); print }' \
    > !{sample_id}.stats
