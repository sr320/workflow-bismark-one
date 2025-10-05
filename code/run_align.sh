#!/usr/bin/env bash
set -euo pipefail

# Load config if present
if [[ -f ./.bismark_env.sh ]]; then
  # shellcheck disable=SC1091
  source ./.bismark_env.sh
else
  echo "Config .bismark_env.sh not found; using defaults." >&2
  bismark_dir=""
  bowtie2_dir=""
  threads=30
  reads_dir="../data/reads/"
  reads_r1_url="https://owl.fish.washington.edu/nightingales/G_macrocephalus/30-1067895835/1D11_R1_001.fastq.gz"
  reads_r2_url="https://owl.fish.washington.edu/nightingales/G_macrocephalus/30-1067895835/1D11_R2_001.fastq.gz"
  output_dir="../output/bismark-prep-align-laptop"
  genome_folder="../data/genome"
fi

effective_reads_dir="${reads_dir}"
if [[ -n "${reads_r1_url:-}" && -n "${reads_r2_url:-}" ]]; then
  mkdir -p "${reads_dir}"
  cd "${reads_dir}"
  echo "Downloading reads..."
  curl -L -O "${reads_r1_url}"
  curl -L -O "${reads_r2_url}"
  effective_reads_dir="$(pwd)/"
  cd - >/dev/null
fi

echo "Using reads directory: ${effective_reads_dir}"

bismark_cmd="bismark"
if [[ -n "${bismark_dir:-}" ]]; then
  bismark_cmd="${bismark_dir%/}/bismark"
fi

mkdir -p "${output_dir}"

shopt -s nullglob
has_pairs=0
for r1 in "${effective_reads_dir}"*_R1.fastq "${effective_reads_dir}"*_R1.fastq.gz; do
  [[ -e "$r1" ]] || continue
  has_pairs=1
  base=$(basename "${r1}")
  sample="${base%_R1.fastq*}"
  r2="${effective_reads_dir}${sample}_R2.fastq"
  [[ -f "${r2}" ]] || r2="${r2}.gz"
  if [[ ! -f "${r2}" ]]; then
    echo "Skipping ${sample}: missing R2 file" >&2
    continue
  fi

  echo "Aligning sample: ${sample}"
  if [[ -n "${bowtie2_dir:-}" ]]; then
    "${bismark_cmd}" \
      --path_to_bowtie "${bowtie2_dir%/}" \
      -genome "${genome_folder}" \
      -p "${threads}" \
      --score_min L,0,-0.6 \
      --non_directional \
      -1 "${r1}" \
      -2 "${r2}" \
      -o "${output_dir}" \
      --basename "${sample}"
  else
    "${bismark_cmd}" \
      -genome "${genome_folder}" \
      -p "${threads}" \
      --score_min L,0,-0.6 \
      --non_directional \
      -1 "${r1}" \
      -2 "${r2}" \
      -o "${output_dir}" \
      --basename "${sample}"
  fi
done

if [[ "${has_pairs}" -eq 0 ]]; then
  echo "No R1 FASTQ files found in ${effective_reads_dir}" >&2
  exit 1
fi


