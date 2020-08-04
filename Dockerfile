# mlcc -i RHEL7.7,Numpy,TensorFlow
# mlcc version: 20181224a: Nov 12 2019

# Install UBI 7.7 backed by lower priority RHEL 7 repos

FROM nvidia/cuda:10.1-cudnn7-runtime-ubi7

WORKDIR /matmul-gpu

ENV NVIDIA_VISIBLE_DEVICES all

RUN set -vx \
\
&& yum-config-manager --enable \
    rhel-7-server-rpms \
    rhel-7-server-extras-rpms \
    rhel-7-server-optional-rpms \
\
&& sed -i '/enabled = 1/ a priority =  1' /etc/yum.repos.d/ubi.repo \
&& sed -i '/enabled = 1/ a priority = 99' /etc/yum.repos.d/redhat.repo \
\
&& yum -y -v install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm" \
\
&& yum -y update \
&& yum clean all


# Install Basic OS Tools

RUN set -vx \
\
&& echo -e '\
set -vx \n\
for (( TRY=1; TRY<=5; TRY++ )); do \n\
    /bin/ls -alFR /usr/lib/.build-id \n\
    /bin/rm -rf /usr/lib/.build-id \n\
    yum -y -v install $@ \n\
    result=$? \n\
    for PKG in $@ ; do \n\
        yum list installed | grep "^$PKG" \n\
        (( result += $? )) \n\
    done \n\
    if (( $result == 0 )); then \n\
        yum clean all \n\
        exit 0 \n\
    else \n\
        echo "Missing packages: ${result} of $@" \n\
    fi \n\
    sleep 10 \n\
done \n\
exit 1 \n' \
> /tmp/yum_install.sh \
\
&& echo -e '\
set -vx \n\
CACHE_DIR="/tmp/download_cache_dir" \n\
for FILE in $@ ; do \n\
    CACHED_FILE="$CACHE_DIR/`basename $FILE`" \n\
    if [ -r "$CACHED_FILE" ]; then \n\
        cp $CACHED_FILE . \n\
    else \n\
        wget $FILE \n\
        if [ -d "$CACHE_DIR" ]; then \n\
            cp `basename $FILE` $CACHED_FILE \n\
        fi \n\
    fi \n\
done \n' \
> /tmp/cached_wget.sh \
\
&& echo -e '\
cd /tmp \n\
for SCRIPT in $@ ; do \n\
    wget -q $SCRIPT -O `basename $SCRIPT` \n\
    /bin/bash `basename $SCRIPT` \n\
done \n' \
> /tmp/run_remote_bash_script.sh \
\
&& chmod +x /tmp/yum_install.sh /tmp/cached_wget.sh /tmp/run_remote_bash_script.sh \
\
&& cd /usr/local \
&& /bin/rm -rf lib64 \
&& ln -s lib lib64 \
\
&& /tmp/yum_install.sh \
    binutils \
    bzip2 \
    findutils \
    gcc \
    gcc-c++ \
    gcc-gfortran \
    git \
    gzip \
    make \
    openssl-devel \
    patch \
    pciutils \
    unzip \
    vim-enhanced \
    wget \
    xz \
    zip



# Try to use Python3.8+
# Install Python v3.8.3, if no python3 already present


RUN set -vx \
\
&& if whereis python3 | grep -q "python3.." ; then \
\
    if yum info python38-devel > /dev/null 2>&1; then \
        /tmp/yum_install.sh python38 python38-devel python38-pip python38-setuptools python38-wheel; \
    else \
        if yum info python3-devel > /dev/null 2>&1; then \
            PYTHON3_DEVEL="python3-devel"; \
        else \
            PYTHON3_DEVEL="python3[0-9]-devel"; \
        fi; \
        /tmp/yum_install.sh python3 python3-pip ${PYTHON3_DEVEL} python3-setuptools python3-wheel; \
    fi; \
\
    ln -s /usr/bin/python3 /usr/local/bin/python3; \
    ln -s /usr/bin/pip3 /usr/local/bin/pip3; \
    for d in /usr/lib/python3*; do PYLIBDIR="$d"; echo 'PYLIBDIR: ' $PYLIBDIR; done; \
    ln -s $PYLIBDIR /usr/local/lib/`basename $PYLIBDIR`; \
    for d in /usr/include/python3*; do PYINCDIR="$d"; echo 'PYINCDIR: ' $PYINCDIR; done; \
    ln -s $PYINCDIR /usr/local/include/`basename $PYINCDIR`; \
\
else \
\
    /tmp/yum_install.sh \
        bzip2-devel \
        expat-devel \
        gdbm-devel \
        libdb4-devel \
        libffi-devel \
        ncurses-devel \
        openssl-devel \
        readline-devel \
        sqlite-devel \
        tk-devel \
        xz-devel \
        zlib-devel; \
    \
    cd /tmp; \
    /tmp/cached_wget.sh "https://www.python.org/ftp/python/3.8.3/Python-3.8.3.tar.xz"; \
    tar -xf Python*.xz; \
    /bin/rm Python*.xz; \
    cd /tmp/Python*; \
    ./configure \
        --enable-optimizations \
        --enable-shared \
        --prefix=/usr/local \
        --with-ensurepip=install \
        LDFLAGS="-Wl,-rpath /usr/local/lib"; \
    make -j`getconf _NPROCESSORS_ONLN` install; \
    \
    cd /tmp; \
    /bin/rm -r /tmp/Python*; \
\
fi \
\
&& cd /usr/local/include \
&& PYTHON_INC_DIR_NAME=`ls -d ./python*` \
&& ALT_PYTHON_INC_DIR_NAME=${PYTHON_INC_DIR_NAME%m} \
&& if [ "$ALT_PYTHON_INC_DIR_NAME" != "$PYTHON_INC_DIR_NAME" ]; then \
    ln -s "$PYTHON_INC_DIR_NAME" "$ALT_PYTHON_INC_DIR_NAME"; \
fi \
\
&& /usr/local/bin/pip3 -v install --upgrade \
    pip \
    setuptools \
\
&& if python --version > /dev/null 2>&1; then \
    whereis python; \
    python --version; \
else \
    cd /usr/bin; \
    ln -s python3 python; \
    cd /usr/local/bin; \
    ln -s python3 python; \
fi \
\
&& whereis python3 \
&& python3 --version \
&& pip3 --version \
&& /bin/ls -RFCa /usr/local/include/python*



# Install CMake v3.17.2

RUN set -vx \
\
&& cd /tmp \
&& /tmp/cached_wget.sh "https://cmake.org/files/v3.17/cmake-3.17.2.tar.gz" \
&& tar -xf cmake*.gz \
&& /bin/rm cmake*.gz \
&& cd /tmp/cmake* \
&& ./bootstrap \
&& make -j`getconf _NPROCESSORS_ONLN` install \
&& cd /tmp \
&& /bin/rm -rf /tmp/cmake* \
&& cmake --version




RUN date; df -h

# Install Numpy

RUN set -vx \
\
&& /usr/local/bin/pip3 -v install \
    numpy \
\
&& /usr/local/bin/python3 -c 'import numpy'


RUN date; df -h

# Install TensorFlow-2

RUN set -vx \
\
&& if [ -d /usr/local/cuda ]; then \
    pip3 install tensorflow-gpu; \
else \
    pip3 install tensorflow; \
fi \
\
&& /usr/local/bin/python3 -c 'import tensorflow as tf; print(tf.__version__)'

EXPOSE 6006

ADD . /matmul-gpu

RUN cat /usr/local/cuda/version.txt 

RUN date; df -h
