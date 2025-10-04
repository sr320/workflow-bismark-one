# Base image from the .def
FROM rocker/rstudio:4.4

ENV DEBIAN_FRONTEND=noninteractive

# ------- System deps (from %post) -------
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-utils aptitude automake build-essential bzip2 cmake coreutils curl debconf default-jdk \
    dialog emboss fakeroot gdebi-core gfortran git gobjc++ hmmer htop infernal less \
    libapparmor1 libbz2-dev libcurl4-openssl-dev libedit2 libfontconfig1 liblzma-dev \
    libncurses5-dev libncurses-dev libncursesw5-dev libpango1.0-dev libpng-dev libreadline-dev \
    libsm6 libsparsehash-dev libssl-dev liburi-escape-xs-perl liburi-perl libxml2 libxrender1 \
    libz-dev libfuse3-3 libxt6 libxtst6 libzmq3-dev locales locales-all man nano ncurses-dev \
    net-tools openssh-client parallel pkg-config psmisc python3 python3-setuptools rsync ruby \
    software-properties-common sqlite3 sudo texinfo tree uidmap unzip wget xorg-dev zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

# ------- Copy & run R package installs (from %files + %post) -------
COPY r_packages_installs.R /tmp/r_packages_installs.R
RUN Rscript /tmp/r_packages_installs.R && rm /tmp/r_packages_installs.R

# ------- Env vars (from %environment) -------
ENV programs_location="/srlab/programs" \
    bamUtil_version="1.0.15" \
    bedtools_version="v2.31.0" \
    bismark_version="0.24.2" \
    bowtie2_version="2.5.4" \
    bwa_version="b92993c" \
    CPC2_version="1.0.1" \
    diamond_version="2.1.9" \
    fastp_version="0.23.4" \
    fastqc_version="0.12.1" \
    gffcompare_version="gffcompare-0.12.6" \
    hisat2_version="2.2.1" \
    kallisto_version="0.51.1" \
    miniforge_version="24.7.1-0" \
    multiqc_version="1.24.1" \
    ncbi_blast_version="2.16.0" \
    ncbi_datasets_version="13.34.0" \
    picard_version="3.4.0" \
    qiime2_version="2024.10" \
    repeatmasker_version="4.1.7-p1" \
    rmblast_version="2.14.1" \
    salmon_version="1.10.0" \
    samtools_version="1.20" \
    stringtie_version="2.2.1" \
    subread_version="2.0.5" \
    trimmomatic_version="0.39" \
    mamba_envs_dir="/srlab/programs/miniforge3-24.7.1-0/envs" \
    PICARD="/srlab/programs/picard.jar" \
    NXF_HOME="/gscratch/srlab/programs/nextflow" \
    APPTAINER_CACHEDIR="/gscratch/scrubbed/samwhite/nextflow-cache" \
    NXF_TEMP="/gscratch/scrubbed/samwhite/nextflow-tmp" \
    NXF_SINGULARITY_CACHEDIR="/gscratch/scrubbed/samwhite/singularity-cache" \
    LC_ALL="C"

# PATH block from %environment
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:\
/srlab/programs:\
/srlab/programs/bamUtil-${bamUtil_version}:\
/srlab/programs/Bismark-${bismark_version}:\
/srlab/programs/bowtie2-${bowtie2_version}-sra-linux-x86_64:\
/srlab/programs/bwa:\
/srlab/programs/CPC2_standalone-${CPC2_version}/bin:\
/srlab/programs/fastqc-${fastqc_version}:\
/srlab/programs/${gffcompare_version}:\
/srlab/programs/hisat2-${hisat2_version}:\
/srlab/programs/kallisto-${kallisto_version}/build/src:\
/srlab/programs/miniforge3-${miniforge_version}/bin:\
/srlab/programs/ncbi-blast-${ncbi_blast_version}+/bin:\
/srlab/programs/ncbi-datasets-${ncbi_datasets_version}:\
/srlab/programs/nextflow:\
/srlab/programs/RepeatMasker:\
/srlab/programs/rmblast-${rmblast_version}/bin:\
/srlab/programs/salmon-latest_linux_x86_64/bin:\
/srlab/programs/samtools-${samtools_version}:\
/srlab/programs/stringtie-${stringtie_version}.Linux_x86_64:\
/srlab/programs/subread-${subread_version}-Linux-x86_64/bin:\
/srlab/programs/Trimmomatic-${trimmomatic_version}:\
/srlab/programs/trf409.linux64"

# ------- Install everything from %post -------
RUN set -eux; \
    threads="40"; \
    mkdir -p /srlab/programs && cd /srlab/programs && \
    \
    # Miniforge (Conda/Mamba)
    wget -q https://github.com/conda-forge/miniforge/releases/download/${miniforge_version}/Miniforge3-${miniforge_version}-Linux-x86_64.sh && \
    bash Miniforge3-${miniforge_version}-Linux-x86_64.sh -b -p ./miniforge3-${miniforge_version} && \
    export PATH="$PATH:/srlab/programs/miniforge3-${miniforge_version}/bin" && \
    mamba init . && . ./miniforge3-${miniforge_version}/etc/profile.d/conda.sh && \
    rm Miniforge3-${miniforge_version}-Linux-x86_64.sh && \
    \
    # Apptainer (inside container; used by Nextflow workflows)
    wget -q https://github.com/apptainer/apptainer/releases/download/v1.4.0/apptainer_1.4.0_amd64.deb && \
    dpkg --install apptainer_1.4.0_amd64.deb && rm apptainer_1.4.0_amd64.deb && \
    \
    # bamUtil
    wget -q https://github.com/statgen/bamUtil/archive/refs/tags/v${bamUtil_version}.tar.gz && \
    tar -xzf v${bamUtil_version}.tar.gz && rm v${bamUtil_version}.tar.gz && \
    cd bamUtil-${bamUtil_version} && \
    sed -i 's|git://github.com/statgen/libStatGen.git|https://github.com/statgen/libStatGen.git|g' Makefile.inc && \
    make cloneLib && make -j ${threads} && cd .. && \
    \
    # bedtools (static)
    wget -q https://github.com/arq5x/bedtools2/releases/download/${bedtools_version}/bedtools.static && \
    mv bedtools.static bedtools && chmod a+x bedtools && \
    \
    # Bismark
    wget -q https://github.com/FelixKrueger/Bismark/archive/refs/tags/v${bismark_version}.zip && \
    unzip -q v${bismark_version}.zip && rm v${bismark_version}.zip && \
    \
    # bowtie2
    wget -q https://github.com/BenLangmead/bowtie2/releases/download/v${bowtie2_version}/bowtie2-${bowtie2_version}-sra-linux-x86_64.zip && \
    unzip -q bowtie2-${bowtie2_version}-sra-linux-x86_64.zip && rm bowtie2-${bowtie2_version}-sra-linux-x86_64.zip && \
    \
    # BWA
    git clone https://github.com/lh3/bwa.git && cd bwa && git checkout ${bwa_version} && make -j ${threads} && cd .. && \
    \
    # CPC2
    wget -q https://github.com/gao-lab/CPC2_standalone/archive/refs/tags/v${CPC2_version}.tar.gz && \
    tar -xzf v${CPC2_version}.tar.gz && rm v${CPC2_version}.tar.gz && \
    cd CPC2_standalone-${CPC2_version}/libs/libsvm/ && \
    gzip -dc libsvm-3.18.tar.gz | tar xf - && cd libsvm-3.18 && make clean && make && cd /srlab/programs && \
    pip3 install --no-cache-dir six biopython && \
    \
    # DIAMOND
    wget -q https://github.com/bbuchfink/diamond/releases/download/v${diamond_version}/diamond-linux64.tar.gz && \
    tar -xzf diamond-linux64.tar.gz && rm diamond-linux64.tar.gz && \
    \
    # fastp
    wget -q http://opengene.org/fastp/fastp.${fastp_version} && mv fastp.${fastp_version} fastp && chmod a+x fastp && \
    \
    # FastQC
    wget -q https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v${fastqc_version}.zip && \
    unzip -q fastqc_v${fastqc_version}.zip && mv FastQC fastqc-${fastqc_version} && rm fastqc_v${fastqc_version}.zip && \
    \
    # gffcompare
    wget -q http://ccb.jhu.edu/software/stringtie/dl/${gffcompare_version}.Linux_x86_64.tar.gz && \
    tar -xzf ${gffcompare_version}.Linux_x86_64.tar.gz && rm ${gffcompare_version}.Linux_x86_64.tar.gz && \
    \
    # HISAT2
    wget -q https://github.com/DaehwanKimLab/hisat2/archive/refs/tags/v${hisat2_version}.tar.gz && \
    tar -xzf v${hisat2_version}.tar.gz && cd hisat2-${hisat2_version} && make -j ${threads} && cd .. && rm v${hisat2_version}.tar.gz && \
    \
    # kallisto
    wget -q https://github.com/pachterlab/kallisto/archive/refs/tags/v${kallisto_version}.tar.gz && \
    tar -xzf v${kallisto_version}.tar.gz && cd kallisto-${kallisto_version} && mkdir build && cd build && cmake .. && make && cd /srlab/programs && rm v${kallisto_version}.tar.gz && \
    \
    # MultiQC (conda env)
    conda config --add channels defaults && conda config --add channels bioconda && conda config --add channels conda-forge && \
    conda config --set channel_priority strict && \
    mamba create -y -n multiqc_env multiqc=${multiqc_version} && \
    \
    # Nextflow
    curl -s https://get.nextflow.io | bash && chmod +x nextflow && \
    \
    # NCBI datasets
    mkdir -p ncbi-datasets-v${ncbi_datasets_version} && cd ncbi-datasets-v${ncbi_datasets_version} && \
    wget -q https://github.com/ncbi/datasets/releases/download/v${ncbi_datasets_version}/linux-amd64.cli.package.zip && \
    unzip -q linux-amd64.cli.package.zip && rm linux-amd64.cli.package.zip && cd .. && \
    \
    # NCBI BLAST+
    wget -q ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/${ncbi_blast_version}/ncbi-blast-${ncbi_blast_version}+-x64-linux.tar.gz && \
    tar -xzf ncbi-blast-${ncbi_blast_version}+-x64-linux.tar.gz && rm ncbi-blast-${ncbi_blast_version}+-x64-linux.tar.gz && \
    \
    # Picard
    wget -q https://github.com/broadinstitute/picard/releases/download/${picard_version}/picard.jar && \
    \
    # QIIME2 env
    conda config --add channels conda-forge && conda config --add channels defaults && conda config --add channels bioconda && \
    conda config --set channel_priority flexible && \
    conda env create -n qiime2-amplicon-${qiime2_version} --file https://data.qiime2.org/distro/amplicon/qiime2-amplicon-${qiime2_version}-py310-linux-conda.yml && \
    \
    # RepeatMasker conda env (h5py)
    conda config --add channels defaults && conda config --add channels bioconda && conda config --add channels conda-forge && \
    conda config --set channel_priority strict && \
    mamba create -y -n repeatmasker-env python=3.8 h5py && \
    \
    # RepeatMasker (delete default DB; symlink to host-mounted famdb later)
    wget -q https://www.repeatmasker.org/RepeatMasker/RepeatMasker-${repeatmasker_version}.tar.gz && \
    tar -xzf RepeatMasker-${repeatmasker_version}.tar.gz && rm RepeatMasker-${repeatmasker_version}.tar.gz && \
    rm -f /srlab/programs/RepeatMasker/Libraries/famdb/* || true && \
    ln -s /gscratch/srlab/programs/RepeatMasker/Libraries/famdb/dfam38_full.0.h5 /srlab/programs/RepeatMasker/Libraries/famdb/dfam38_full.0.h5 && \
    ln -s /gscratch/srlab/programs/RepeatMasker/Libraries/famdb/rmlib.config /srlab/programs/RepeatMasker/Libraries/famdb/rmlib.config && \
    \
    # RMBLAST
    wget -q https://www.repeatmasker.org/rmblast/rmblast-${rmblast_version}+-x64-linux.tar.gz && \
    tar -xzf rmblast-${rmblast_version}+-x64-linux.tar.gz && rm rmblast-${rmblast_version}+-x64-linux.tar.gz && \
    \
    # salmon
    wget -q https://github.com/COMBINE-lab/salmon/releases/download/v${salmon_version}/salmon-${salmon_version}_linux_x86_64.tar.gz && \
    tar -xzf salmon-${salmon_version}_linux_x86_64.tar.gz && rm salmon-${salmon_version}_linux_x86_64.tar.gz && \
    \
    # samtools (build)
    wget -q https://github.com/samtools/samtools/releases/download/${samtools_version}/samtools-${samtools_version}.tar.bz2 && \
    tar -xjf samtools-${samtools_version}.tar.bz2 && cd samtools-${samtools_version} && ./configure && make -j ${threads} && cd .. && rm samtools-${samtools_version}.tar.bz2 && \
    \
    # subread (featureCounts)
    wget -q https://sourceforge.net/projects/subread/files/subread-${subread_version}-Linux-x86_64.tar.gz && \
    tar -xzf subread-${subread_version}-Linux-x86_64.tar.gz && rm subread-${subread_version}-Linux-x86_64.tar.gz && \
    \
    # Trimmomatic
    wget -q http://www.usadellab.org/cms/uploads/supplementary/Trimmomatic/Trimmomatic-${trimmomatic_version}.zip && \
    unzip -q Trimmomatic-${trimmomatic_version}.zip && chmod +x -R Trimmomatic-${trimmomatic_version} && rm Trimmomatic-${trimmomatic_version}.zip && \
    \
    # StringTie
    wget -q http://ccb.jhu.edu/software/stringtie/dl/stringtie-${stringtie_version}.Linux_x86_64.tar.gz && \
    tar -xzf stringtie-${stringtie_version}.Linux_x86_64.tar.gz && rm stringtie-${stringtie_version}.Linux_x86_64.tar.gz && \
    \
    # TRF
    wget -q https://github.com/Benson-Genomics-Lab/TRF/releases/download/v4.09.1/trf409.linux64 && \
    chmod +x trf409.linux64

# Create mount point for RepeatMasker (host bind)
RUN mkdir -p /gscratch/srlab/programs/RepeatMasker

EXPOSE 8787