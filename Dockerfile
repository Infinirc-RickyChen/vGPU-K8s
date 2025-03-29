FROM ubuntu:24.04


ENV DEBIAN_FRONTEND=noninteractive


RUN apt-get update && apt-get install -y \
    wget \
    curl \
    vim \
    nano \
    git \
    sudo \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    htop \
    libncurses5-dev \
    libncursesw5-dev \
    gnupg \
    && rm -rf /var/lib/apt/lists/*


RUN ln -s /lib/x86_64-linux-gnu/libncurses.so.6 /lib/x86_64-linux-gnu/libtinfo.so.5


RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    apt-get update



RUN apt-get install -y --no-install-recommends \
    cuda-compiler-12-1 \
    cuda-libraries-12-1 \
    cuda-libraries-dev-12-1 \
    cuda-command-line-tools-12-1 \
    cuda-nvcc-12-1 \
    cuda-cudart-12-1 \
    cuda-cudart-dev-12-1 \
    cuda-nvrtc-12-1 \
    cuda-nvrtc-dev-12-1 \
    cuda-cuobjdump-12-1 \
    libcublas-12-1 \
    libcublas-dev-12-1 \
    && rm -rf /var/lib/apt/lists/* \
    && rm cuda-keyring_1.1-1_all.deb


ENV PATH="/usr/local/cuda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"


RUN apt-get update && apt-get install -y \
    git \
    cmake \
    libncurses5-dev \
    libncursesw5-dev \
    libdrm-dev \
    libsystemd-dev \
    libudev-dev \
    && git clone https://github.com/Syllo/nvtop.git \
    && mkdir -p nvtop/build && cd nvtop/build \
    && cmake .. \
    && make -j$(nproc) \
    && make install \
    && cd / && rm -rf nvtop \
    && rm -rf /var/lib/apt/lists/*


RUN apt-get update && \
    apt-get install -y wget bzip2 ca-certificates && \
    wget https://repo.anaconda.com/archive/Anaconda3-2023.09-0-Linux-x86_64.sh -O /tmp/anaconda.sh && \
    bash /tmp/anaconda.sh -b -p /opt/anaconda && \
    rm /tmp/anaconda.sh && \
    rm -rf /var/lib/apt/lists/*


ENV PATH="/opt/anaconda/bin:${PATH}"


WORKDIR /workspace


CMD ["/bin/bash"]
