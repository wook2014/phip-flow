# PHIP-FLOW
A Nextflow pipeline for Common Phage Immuno-Precipitation Sequencing experiments.
See the [Documentation](https://matsengrp.github.io/phippery/introduction.html)
for more details and usage examples.

## Quickstart 

Install `Nextflow` by using the following command: 

    curl -s https://get.nextflow.io | bash 
    
Download the `Docker` Desktop, there exists several distributions packaged for
various linux flavors

    curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh

Launch the pipeline execution with the following command: 

    nextflow run matsengrp/phip-flow -r V1.12 -profile docker

Note: the ``-r VX.XX`` command runs the specified stable release version of the pipeline. 
For running the bleeding edge (not generally recommended) you may also specify ``-r main``.
You may also specify any of the 
[parameters](https://matsengrp.github.io/phippery/alignments-pipeline.html#parameters) 
for changing the input data and workflow behavior.

Note: the ``phippery`` [Dockerfile](https://github.com/matsengrp/phippery/blob/main/Dockerfile) 
contains all the required dependencies except those for ``EdgeR`` and ``BEER``, 
for which the maintainers of that package host their own public image.

[![Docker Repository on Quay](https://quay.io/repository/hdc-workflows/phippery/status "Docker Repository on Quay")](https://quay.io/repository/hdc-workflows/phippery)

## Paired-end alignment with Bowtie 2

Use one row per sample in the sample CSV. The existing `fastq_filepath`
column holds R1. Add `fastq_filepath_r2` for R2 from the same sample.
The two files must list the read pairs in the same order. Each mate can
be an uncompressed FASTQ or a gzipped FASTQ.

```csv
fastq_filepath,fastq_filepath_r2
ngs/sample_R1.fastq.gz,ngs/sample_R2.fastq.gz
```

Run from the directory containing the sample and peptide tables, using the
path to this checkout:

```bash
nextflow run /path/to/phip-flow/main.nf -profile docker \
    --paired_end true \
    --sample_table sample_table.csv \
    --peptide_table peptide_table.csv \
    --reads_prefix "$PWD" \
    --dataset_prefix batch_20261119 \
    --results results_paired \
    --run_edgeR false
```

This example generates counts with edgeR disabled. Enable it if your
sample annotations meet the edgeR workflow's requirements. Relative
FASTQ paths are resolved against `--reads_prefix`. The Docker profile
pulls the pinned-by-tag Bowtie 2 image for indexing and alignment.
To run outside Docker, install Bowtie 2, SAMtools, and the other workflow
dependencies in the active environment and select `-profile standard`.

Bowtie 2 defaults to end-to-end alignment with inward-facing mates
(`--fr`). Trim adapters or flanking sequence first if they extend
beyond the reference oligos. Pass assay-specific orientation,
insert-length, score, or trimming settings via `--bowtie2_optional_args`.
For example, `--bowtie2_optional_args '--trim3 8'` trims eight bases from
the 3' end of both reads. Bowtie 2 has its own scoring and trimming
options. The Bowtie 1 parameters `read_length`, `oligo_tile_length`,
`n_mismatches`, and `bowtie_optional_args` apply to single-end mode.
Keep Bowtie 2's default SAM reporting to include unmapped reads in the
QC denominator.

Before count replication for identical oligos, each properly paired
primary alignment contributes one fragment count to its peptide
reference. Unmapped, discordant, and lone mate alignments contribute
zero. The sample QC statistics use the full SAM and report read-level
metrics. Multi-mapping pairs can still be assigned to one of the
best-scoring references by Bowtie 2.

Single-end runs still accept the original one-column input and use
Bowtie 1 when `--paired_end` is false (the default).

## Batch output names and work directories

Pass `--dataset_prefix batch_20261119` to name the published results for
a batch. This gives names such as `batch_20261119.phip`,
`batch_20261119_counts.csv.gz`, `batch_20261119-tall.csv.gz`,
`batch_20261119_PhIPData.rds`, and
`batch_20261119_organism.summary.csv.gz` when their respective outputs are
enabled. Use a different prefix for each batch that shares a results
directory. Omitting the option keeps the original `data` defaults and
the original RDS and organism summary names.

With Nextflow 24.04 or newer, a successful run automatically removes
its own task directories from the local `work` directory after copying
results. Failed runs retain their task files. Cleaned runs cannot reuse
those files with `-resume`. To keep the task files for a successful run,
pass `-c keep-work.config` and put `cleanup = false` in that config.

## edgeR output

`edgeR_fdr` contains numeric BH-adjusted p values, calculated separately
across peptides for each sample. `edgeR_logpval` contains the unadjusted
one-sided p values on the `-log10` scale. `edgeR_hits` marks values of
`edgeR_fdr` strictly below `--edgeR_threshold`.

These assays are included in the published PhIPData RDS and `.phip`
dataset, and in the CSV exports when enabled.

