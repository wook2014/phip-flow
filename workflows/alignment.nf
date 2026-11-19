#!/usr/bin/env nextflow

// Using DSL-2
nextflow.enable.dsl=2

/*
Validate and output the sample table
*/
process validate_sample_table {
    input: path samples
    output: path "validated_sample_table.csv"
    script:
    """
    validate-sample-table.py \
        -s $samples \
        -o validated_sample_table.csv \
        --run_zscore_fit_predict ${params.run_zscore_fit_predict} \
        --paired_end ${params.paired_end}
    """  
}

/*
Validate and output the peptide table
*/
// TODO fix script for no peptide id provided
process validate_peptide_table{
    input: path peptides
    output: path "validated_peptide_table.csv"
    script:
    """
    validate-peptide-table.py \
        -p $peptides \
        -o validated_peptide_table.csv
    """
}

// CONVERT PEPTIDE METADATA TO FASTA
process generate_fasta_reference {
    input: path peptide_table
    output: path "peptides.fasta"
    script:
    """
    generate-fasta.py \
        -pt $peptide_table \
        -o peptides.fasta
    """
}


// GENERATE INDEX
process generate_index {
    if (params.paired_end.toString() == 'true')
        label 'bowtie2'
    // Create the index directory on the host so Nextflow can clean it after Docker runs.
    beforeScript 'mkdir -p peptide_index'
    input:
    path "oligo_fasta"
    output:
    tuple val("peptide_ref"), path("peptide_index")
    shell:    
    template "generate_index.sh"
}


// ALIGN ALL SAMPLES TO THE REFERENCE
process short_read_alignment {
    label 'alignment_tool'
    if (params.paired_end.toString() == 'true')
        label 'bowtie2'
    input:
    tuple val(sample_id), path(index), path(read1, stageAs: 'reads/r1/*'), path(read2, stageAs: 'reads/r2/*')
    output:
    tuple val(sample_id), path("${sample_id}.sam")
    shell:
    template "short_read_alignment.sh"

}


// COMPUTE ALIGNMENT STATS FOR ALL STATS
process sam_to_stats {
    input:
    tuple val(sample_id), path(sam_file)
    output:
    path "${sample_id}.stats"
    shell:
    template "sam_to_stats.sh"
}


// COMPUTE COUNTS FOR ALL SAMPLES
process sam_to_counts {
    input: tuple val(sample_id), path(sam_file)
    output: path "${sample_id}.counts"
    shell:
    template "sam_to_counts.sh"
}


// COLLECT AND MERGE ALL 
// TODO move to bin script remove from phippery
process collect_phip_data {
    input:
    path all_counts_files
    path all_alignment_stats
    path sample_table 
    path peptide_table 
    output:
    path "data.phip"

    shell:
    """
    merge-counts-stats.py \
        -st ${sample_table} \
        -pt ${peptide_table} \
        -cfp "*.counts" \
        -sfp "*.stats" \
        -o data.phip
    """
}

process replicate_counts {
    input: path ds
    output: path "replicated_counts.phip"
    script: 
    """
    replicate-counts.py \
        -ds ${ds} \
        -o replicated_counts.phip
    """
}

workflow ALIGN {

    main:
        sample_ch = Channel.fromPath(params.sample_table)
        peptide_ch = Channel.fromPath(params.peptide_table)

        validate_sample_table(sample_ch)
        validate_peptide_table(peptide_ch) \
            | generate_fasta_reference | generate_index

        validate_sample_table.out
            .splitCsv(header:true )
            .map{ row -> 
                def reads_prefix = file(params.reads_prefix)
                def read1 = file(reads_prefix.resolve(row.fastq_filepath), checkIfExists: true, glob: false)
                def read2 = []
                if (params.paired_end.toString() == 'true') {
                    read2 = file(reads_prefix.resolve(row.fastq_filepath_r2), checkIfExists: true, glob: false)
                    if (read1.toRealPath() == read2.toRealPath())
                        error "Sample ${row.sample_id}: R1 and R2 refer to the same FASTQ file"
                }
                tuple("peptide_ref", row.sample_id, read1, read2)
            }
            .set { samples_ch }

        short_read_alignment(
            generate_index.out
                .cross(samples_ch)
                .map{ ref, sample ->
                    tuple(
                        sample[1],          // sample_id
                        file(ref[1]),       // index files
                        sample[2],          // R1 or single-end FASTQ
                        sample[3],          // R2 FASTQ or empty list
                    )
                }
        ) | (sam_to_counts & sam_to_stats)

        ds = collect_phip_data(
            sam_to_counts.out.toSortedList(),
            sam_to_stats.out.toSortedList(),
            validate_sample_table.out,
            validate_peptide_table.out
        )

        final_output = ds
        if ( params.replicate_sequence_counts )
            final_output = replicate_counts(ds)

    emit:
        final_output
}
