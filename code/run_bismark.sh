#!/usr/bin/env bash
set -euo pipefail

# Load config if present (from Quarto or previous runs)
if [[ -f ./.bismark_env.sh ]]; then
  # shellcheck disable=SC1091
  source ./.bismark_env.sh
fi

# Defaults if unset (can be overridden by .bismark_env.sh or env)
: "${bismark_dir:=}"
: "${bowtie2_dir:=}"
: "${threads:=30}"
: "${genome_path_or_url:=https://gannet.fish.washington.edu/v1_web/owlshell/bu-github/project-cod-temperature/data/GCF_031168955.1_ASM3116895v1_genomic.fna}"
: "${reads_dir:=../data/reads/}"
: "${reads_r1_url:=https://owl.fish.washington.edu/nightingales/G_macrocephalus/30-1067895835/1D11_R1_001.fastq.gz}"
: "${reads_r2_url:=https://owl.fish.washington.edu/nightingales/G_macrocephalus/30-1067895835/1D11_R2_001.fastq.gz}"
: "${output_dir:=../output/bismark-prep-align-laptop}"

mkdir -p "${output_dir}"
mkdir -p ../data

# Prepare genome folder
genome_folder=""
if [[ "${genome_path_or_url}" =~ ^https?:// ]]; then
  mkdir -p ../data/genome
  cd ../data/genome
  url="${genome_path_or_url}"
  fname=$(basename "${url}")
  echo "Downloading genome: ${url}"
  curl -L -O "${url}"
  if [[ "${fname}" == *.gz ]]; then
    gunzip -f "${fname}"
    fname="${fname%.gz}"
  fi
  genome_folder="$(pwd)"
  cd - >/dev/null
elif [[ -d "${genome_path_or_url}" ]]; then
  genome_folder="${genome_path_or_url%/}"
elif [[ -f "${genome_path_or_url}" ]]; then
  mkdir -p ../data/genome
  cp -f "${genome_path_or_url}" ../data/genome/
  if [[ "${genome_path_or_url}" == *.gz ]]; then
    gunzip -f ../data/genome/$(basename "${genome_path_or_url}")
  fi
  genome_folder="../data/genome"
else
  echo "Genome source not found: ${genome_path_or_url}" >&2
  exit 1
fi

echo "Genome folder: ${genome_folder}"

# Build Bismark genome index
prep_cmd="bismark_genome_preparation"
if [[ -n "${bismark_dir}" ]]; then
  prep_cmd="${bismark_dir%/}/bismark_genome_preparation"
fi

aligner_opt=()
if [[ -n "${bowtie2_dir}" ]]; then
  aligner_opt=(--path_to_aligner "${bowtie2_dir%/}")
fi

"${prep_cmd}" \
  --verbose \
  --parallel "${threads}" \
  "${aligner_opt[@]}" \
  "${genome_folder}"

# Acquire reads (optional URLs) and align
effective_reads_dir="${reads_dir}"
if [[ -n "${reads_r1_url}" && -n "${reads_r2_url}" ]]; then
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
if [[ -n "${bismark_dir}" ]]; then
  bismark_cmd="${bismark_dir%/}/bismark"
fi

bowtie_opt=()
if [[ -n "${bowtie2_dir}" ]]; then
  bowtie_opt=(--path_to_bowtie "${bowtie2_dir%/}")
fi

mkdir -p "${output_dir}"

shopt -s nullglob
has_pairs=0
for r1 in \
  "${effective_reads_dir}"*_R1*.fastq \
  "${effective_reads_dir}"*_R1*.fastq.gz \
  "${effective_reads_dir}"*_R1*.fq \
  "${effective_reads_dir}"*_R1*.fq.gz; do
  [[ -e "$r1" ]] || continue
  has_pairs=1
  base=$(basename "${r1}")
  sample="${base%%_R1*}"
  r2="${r1/_R1/_R2}"
  if [[ ! -f "${r2}" ]]; then
    echo "Skipping ${sample}: missing R2 file" >&2
    continue
  fi

  echo "Aligning sample: ${sample}"
  "${bismark_cmd}" \
    "${bowtie_opt[@]}" \
    -genome "${genome_folder}" \
    -p "${threads}" \
    --score_min L,0,-0.6 \
    --non_directional \
    -1 "${r1}" \
    -2 "${r2}" \
    -o "${output_dir}" \
    --basename "${sample}"
done

if [[ "${has_pairs}" -eq 0 ]]; then
  echo "No R1 FASTQ files found in ${effective_reads_dir}" >&2
  exit 1
fi


