#!/bin/bash
set -euo pipefail
shopt -s nullglob

# Set directories and files
reads_dir="/mmfs1/gscratch/scrubbed/strigg/analyses/20250731_methylseq/raw-reads/"
genome_folder="/mmfs1/gscratch/scrubbed/sr320/github/project-chilean-mussel/data/Mchi"
output_dir="."
mkdir -p "$output_dir"

for r1 in "${reads_dir}"*_R1.fastq.gz; do
  sample=$(basename "$r1" "_R1.fastq.gz")
  r2="${reads_dir}${sample}_R2.fastq.gz"

  if [[ ! -f "$r2" ]]; then
    echo "Missing R2 file for $sample, skipping..."
    continue
  fi

  echo "Processing $sample"
  bismark \
    -genome "$genome_folder" \
    -p 8 \
    -score_min L,0,-0.8 \
    -1 "$r1" \
    -2 "$r2" \
    -o "$output_dir" \
    --basename "$sample" \
    2> "${output_dir}/${sample}_bismark.log"
done
