FROM alpine:3.18.2

RUN apk add --no-cache bash

# Build and install MUSCLE (GPL 3.0)
RUN apk add --no-cache alpine-sdk binutils && \
    git clone https://github.com/rcedgar/muscle.git && \
    cd muscle && \
    git checkout --quiet 5.1.0 && \
    cd src && \
    make LDFLAGS2=-static && \
    strip ./Linux/muscle && \
    cp ./Linux/muscle /usr/bin/muscle && \
    chmod a+x /usr/bin/muscle && \
    cd ../.. && \
    rm -rf muscle && \
    apk del --no-cache alpine-sdk binutils

# Build and install RAxML-NG (AGPL 3.0)
RUN apk add --no-cache alpine-sdk clang binutils cmake bison flex && \
    export CC=clang CXX=clang++ && \
    git clone --recursive https://github.com/amkozlov/raxml-ng.git && \
    cd raxml-ng && \
    git checkout --quiet 1.2.0 && \
    sed -i '6i #include <ctime>' src/util/EnergyMonitor.hpp && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DSTATIC_BUILD=ON .. && \
    make && \
    strip ./bin/raxml-ng-static && \
    cp ./bin/raxml-ng-static /usr/bin/raxml-ng && \
    chmod a+x /usr/bin/raxml-ng && \
    cd ../.. && \
    rm -rf raxml-ng && \
    apk del --no-cache alpine-sdk clang binutils cmake bison flex

# Build and install ecceTERA (CeCILL 2.1)
RUN apk add --no-cache alpine-sdk clang binutils cmake && \
    export CC=clang CXX=clang++ && \
    git clone https://github.com/celinescornavacca/ecceTERA.git && \
    cd ecceTERA && \
    git checkout --quiet c600321a && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=98 \
        -DCMAKE_EXE_LINKER_FLAGS="-static" \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
          .. && \
    make && \
    strip ./bin/ecceTERA && \
    cp ./bin/ecceTERA /usr/bin/ecceTERA && \
    chmod a+x /usr/bin/ecceTERA && \
    cd ../.. && \
    rm -rf ecceTERA && \
    apk del --no-cache alpine-sdk clang binutils cmake

# Install NCBI Datasets tools (public domain, no source?)
ARG TARGETOS TARGETARCH
RUN apk add --no-cache binutils && \
    wget -O /usr/bin/datasets "https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/${TARGETOS}-${TARGETARCH}/datasets" && \
    strip /usr/bin/datasets && \
    chmod a+x /usr/bin/datasets && \
    apk del --no-cache binutils

# Install Python with packages
RUN apk add --no-cache python3 py3-pip py3-numpy py3-six py3-biopython

# Create unprivileged user
RUN adduser -h /home/tts -s /bin/bash tts -D

# Install and configure PostgreSQL
ENV PGDATA=/home/tts/.local/share/postgresql
RUN apk add --no-cache postgresql15 && \
    mkdir /run/postgresql && \
    chown tts:tts /run/postgresql && \
    chmod 700 /run/postgresql
USER tts
WORKDIR /home/tts
RUN initdb && \
    mkdir -p $HOME/.cache

# Download CRISPRCasdb dump
RUN wget -O ccpp_db.zip "https://crisprcas.i2bc.paris-saclay.fr/Home/DownloadFile?filename=ccpp_db.zip"

# Install additional Python packages
RUN pip install "psycopg[binary,pool]" ete3 superrec2 && \
    rm -rf $HOME/.cache/pip

# Add Python scripts
ENV PATH="$PATH:/home/tts/.local/bin"
COPY --chown=tts *.py $HOME

CMD pg_ctl start --log="$HOME/.cache/postgresql.log" --silent && /bin/bash
