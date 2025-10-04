#!/bin/bash
# Set directories and files
reads_dir="/mmfs1/gscratch/scrubbed/strigg/analyses/20250731_methylseq/raw-reads/"
genome_folder="/mmfs1/gscratch/scrubbed/sr320/github/project-chilean-mussel/data/Mchi"
output_dir="."
checkpoint_file="completed_samples.log"

# Create the checkpoint file if it doesn't exist
touch "${checkpoint_file}"

# Get the list of sample files and corresponding sample names
files=(${reads_dir}*_R1.fastq)
file="${files[$SLURM_ARRAY_TASK_ID]}"
sample_name=$(basename "$file" "_R1.fastq")

echo "Processing sample: ${sample_name}"

# Run Bismark
bismark \
    -genome "${genome_folder}" \
    -p 8 \
    -score_min L,0,-0.8 \
    --non_directional \
    -1 "${reads_dir}${sample_name}_R1.fastq" \
    -2 "${reads_dir}${sample_name}_R2.fastq" \
    -o "${output_dir}" \
    --basename "${sample_name}" \
    2> "${sample_name}-${SLURM_ARRAY_TASK_ID}-bismark_stderr.log"