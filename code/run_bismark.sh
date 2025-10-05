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

# Resolve absolute genome path to avoid cwd issues
genome_abs="${genome_folder}"
if [[ -d "${genome_folder}" ]]; then
  genome_abs="$(cd "${genome_folder}" && pwd)"
fi

# Ensure genome FASTA is accessible as .fa/.fasta (Bismark discovery)
# Decompress any .gz FASTA files
if compgen -G "${genome_folder}"/*.fa.gz > /dev/null || compgen -G "${genome_folder}"/*.fasta.gz > /dev/null || compgen -G "${genome_folder}"/*.fna.gz > /dev/null; then
  gunzip -f "${genome_folder}"/*.fa.gz 2>/dev/null || true
  gunzip -f "${genome_folder}"/*.fasta.gz 2>/dev/null || true
  gunzip -f "${genome_folder}"/*.fna.gz 2>/dev/null || true
fi

# If only .fna exists, symlink to .fa so Bismark can find it
if ! compgen -G "${genome_folder}"/*.fa > /dev/null && ! compgen -G "${genome_folder}"/*.fasta > /dev/null; then
  if compgen -G "${genome_folder}"/*.fna > /dev/null; then
    for f in "${genome_folder}"/*.fna; do
      base="$(basename "${f%.fna}")"
      ln -sf "${f}" "${genome_folder}/${base}.fa"
    done
  fi
fi

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

# Resolve bismark executable from bismark_dir, PATH, or download locally
bismark_cmd=""
if [[ -n "${bismark_dir}" && -x "${bismark_dir%/}/bismark" ]]; then
  bismark_cmd="${bismark_dir%/}/bismark"
elif command -v bismark >/dev/null 2>&1; then
  bismark_cmd="bismark"
elif [[ -x "../code/.tools/bismark/bismark" ]]; then
  bismark_cmd="../code/.tools/bismark/bismark"
else
  echo "bismark not found on PATH or via bismark_dir; attempting local download..." >&2
  set -x
  mkdir -p ../code/.tools && cd ../code/.tools
  ver="0.24.2"
  curl -L -O "https://github.com/FelixKrueger/Bismark/archive/refs/tags/v${ver}.zip"
  unzip -q "v${ver}.zip" && rm "v${ver}.zip"
  mv "Bismark-${ver}" bismark
  cd - >/dev/null
  set +x
  bismark_cmd="../code/.tools/bismark/bismark"
fi

# Resolve Bowtie2/HISAT2 path or attempt local Bowtie2 download if missing
bowtie_opt=()
if [[ -n "${bowtie2_dir}" && -x "${bowtie2_dir%/}/bowtie2" ]]; then
  bowtie_opt=(--path_to_bowtie2 "${bowtie2_dir%/}")
elif command -v bowtie2 >/dev/null 2>&1; then
  bowtie_opt=()
elif command -v hisat2 >/dev/null 2>&1; then
  hisat_dir="$(dirname "$(command -v hisat2)")"
  bowtie_opt=(--path_to_hisat2 "${hisat_dir}")
elif [[ -x "../code/.tools/bowtie2/bowtie2" ]]; then
  bowtie_opt=(--path_to_bowtie2 "../code/.tools/bowtie2")
else
  echo "Bowtie2/HISAT2 not found; attempting local Bowtie2 download..." >&2
  set -x
  mkdir -p ../code/.tools && cd ../code/.tools
  bowtie2_ver="2.5.4"
  os="$(uname -s)"; arch="$(uname -m)"
  asset=""
  if [[ "$os" == "Linux" && "$arch" == "x86_64" ]]; then
    asset="sra-linux-x86_64"
  elif [[ "$os" == "Darwin" && "$arch" == "x86_64" ]]; then
    asset="macos-x86_64"
  elif [[ "$os" == "Darwin" && "$arch" == "arm64" ]]; then
    asset="macos-arm64"
  fi
  if [[ -n "$asset" ]]; then
    curl -L -O "https://github.com/BenLangmead/bowtie2/releases/download/v${bowtie2_ver}/bowtie2-${bowtie2_ver}-${asset}.zip"
    unzip -q "bowtie2-${bowtie2_ver}-${asset}.zip"
    rm -f "bowtie2-${bowtie2_ver}-${asset}.zip"
    mv "bowtie2-${bowtie2_ver}-${asset}" bowtie2
    cd - >/dev/null
    set +x
    bowtie_opt=(--path_to_bowtie2 "../code/.tools/bowtie2")
  else
    cd - >/dev/null || true
    set +x
    echo "Unsupported OS/arch for auto Bowtie2 download. Install Bowtie2 or set bowtie2_dir." >&2
    exit 1
  fi
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
    -genome "${genome_abs}" \
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


