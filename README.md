# workflow-bismark-one

Simple, reproducible Bismark genome preparation and paired-end alignment workflow. Use it either via Quarto (`code/bismark-prep-align.qmd`) for a narrated, reproducible report, or via shell scripts (`code/run_bismark.sh`) for batch/CLI execution. A minimal Docker image is included to run on machines without preinstalled Bismark/Bowtie2.

### What this template does
- **Genome prep**: Downloads or uses a provided FASTA and builds Bismark/Bowtie2 indexes.
- **Paired-end alignment**: Finds `*_R1.fastq[.gz]` and `*_R2.fastq[.gz]` pairs and runs Bismark.
- **Test data**: The default genome and read URLs in the QMD and scripts are treated as test data to verify the workflow.
- **Logs**: Standard output/err from Quarto chunks or shell runs can be saved as logs for troubleshooting and provenance.

---

## Quick start

You can run this workflow in two ways:

1) Docker container (recommended for portability)
2) Local install (use your existing Bismark/Bowtie2)

Both approaches support either the Quarto document or the shell scripts.

---

## Option 1: Run with Docker

Two Dockerfiles are provided:
- `Dockerfile.bismark`: minimal image with Bismark and Bowtie2 suitable for this workflow.
- `Dockerfile`: larger RStudio-based image with many genomics tools (optional).

Build the minimal image:

```bash
cd /Users/sr320/GitHub/workflow-bismark-one
docker build -f Dockerfile.bismark -t bismark-min:latest .
```

Run the container, mounting the repo so outputs appear on your host:

```bash
docker run --rm -it \
  -v /Users/sr320/GitHub/workflow-bismark-one:/work \
  -w /work/code \
  bismark-min:latest bash
```

Inside the container you can:
- Render the Quarto workflow (generates a self-contained HTML report):
  ```bash
  # Requires Quarto if installed in the container; otherwise use the .sh path below
  # If quarto is not present in the minimal image, run the shell script instead
  ```
- Run the shell script workflow:
  ```bash
  bash run_bismark.sh | tee ../code/run_bismark.log
  ```

Notes:
- The minimal image includes `bismark`, `bowtie2`, and `samtools`. If you prefer RStudio or Quarto inside Docker, build and run using the larger `Dockerfile` and expose port 8787 as needed.

---

## Option 2: Run locally without Docker

Requirements on your PATH:
- Bismark >= 0.24
- Bowtie2 >= 2.5
- curl, gzip, tar, bash

If Bismark/Bowtie2 are not on PATH, you can provide explicit paths via variables (see below).

---

## Using the Quarto workflow (`code/bismark-prep-align.qmd`)

Open `code/bismark-prep-align.qmd` and edit the first chunk “Set variables”. Key variables:
- `bismark_dir` and `bowtie2_dir`: leave empty to use tools on PATH; otherwise set installation directories.
- `threads`: number of threads.
- `genome_path_or_url`: local FASTA/dir or an HTTP(S) URL to a `.fa/.fna[.gz]`. Defaults use test-data.
- `reads_dir`: local directory containing pairs named `*_R1.fastq[.gz]` and `*_R2.fastq[.gz]`.
- `reads_r1_url` and `reads_r2_url`: URLs to download one paired sample (treated as test-data when set).
- `output_dir`: where Bismark outputs will be written.

Render to HTML from the repo root or from `code/`:

```bash
quarto render code/bismark-prep-align.qmd
```

What it does:
- Writes a small config file `code/.bismark_env.sh` with your settings.
- Prepares the genome folder (downloads and decompresses if URL provided).
- Builds the Bismark genome index.
- Optionally downloads the paired reads if URLs are provided; otherwise uses files in `reads_dir`.
- Aligns all discovered pairs and writes outputs to `output_dir`.

Outputs and logs:
- Alignment results are written under `output_dir`.
- Chunk output is visible in the rendered HTML. You can also pipe Quarto render logs:
  ```bash
  quarto render code/bismark-prep-align.qmd 2>&1 | tee code/align.log
  ```

---

## Using the shell scripts

There are two main scripts in `code/`:
- `run_bismark.sh`: end-to-end run using the current config.
- `bismark-prep-align.qmd`: the Quarto document; not a script, but it writes `.bismark_env.sh` which the script can consume.

Configuration precedence for `run_bismark.sh`:
1. Values exported in `code/.bismark_env.sh` (auto-written by the QMD or by you).
2. Environment variables set in your shell before running.
3. Script defaults.

Run the script and capture a log:

```bash
cd code
bash run_bismark.sh | tee run_bismark.log
```

What it does:
- If `reads_r1_url` and `reads_r2_url` are set, downloads those reads into `reads_dir`.
- Detects all `*_R1.fastq[.gz]` files and matches to `*_R2.fastq[.gz]`.
- Runs `bismark_genome_preparation` and `bismark` with optional `--path_to_bowtie` when `bowtie2_dir` is provided.

Outputs and logs:
- Bismark outputs go to `output_dir`.
- `code/run_bismark.log` is an example of capturing script output with `tee`.
- `code/align.log` and `code/genome_prep.log` are example log filenames you can use for troubleshooting.

---

## Variables and “test-data”

Defaults in the QMD and scripts reference public URLs for a genome FASTA and paired reads. Treat these as **test-data** to validate the workflow end-to-end. For real analyses, change:
- `genome_path_or_url` to a local FASTA or your own URL.
- `reads_dir` to a directory containing your FASTQ pairs; remove the read URLs.

---

## Robustness and portability notes

- The workflow detects URL vs local file vs directory for the genome and will download/decompress as needed.
- If `bismark_dir` and `bowtie2_dir` are empty, tools are expected on PATH; otherwise they are invoked via full paths.
- Script uses `set -euo pipefail` and guards missing paired files.
- Works on Linux and macOS; for Windows, use Docker.
- For large genomes, ensure sufficient disk and memory for index building.

---

## Folder layout

- `code/`
  - `bismark-prep-align.qmd`: Quarto workflow.
  - `run_bismark.sh`: non-interactive workflow runner.
  - `.bismark_env.sh`: small env file written by the QMD (and read by the script).
  - `*.log`: optional logs captured via `tee`.
- `data/`
  - `genome/`: downloaded or copied genome and Bismark index.
  - `reads/`: input FASTQ files if downloaded.
- `output/`
  - `bismark-prep-align-laptop/`: default alignment outputs.

---

## Troubleshooting

- No paired files found: verify `reads_dir` and that files are named `*_R1.fastq[.gz]` and `*_R2.fastq[.gz]`.
- Bismark/Bowtie2 missing: install locally or use Docker; or set `bismark_dir`/`bowtie2_dir`.
- Genome not found: ensure `genome_path_or_url` points to an existing file/dir or reachable URL.
- Permission errors in Docker: ensure you mounted the repo and are writing to a host-writable path.

---

## License

MIT
