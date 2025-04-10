FROM ubuntu:jammy-20240427

SHELL ["/bin/bash", "-c"]

WORKDIR /user/lib

RUN apt-get update && \
    apt-get install -y \
    autoconf automake bzip2 ca-certificates cmake curl gcc-10 git jq libatlas-base-dev libc6-dev \
    libedit-dev libglib2.0-dev libssl-dev libtool make ninja-build pkg-config python3 python3-pip \
    sshfs udev zlib1g-dev
RUN pip install -U pip && pip install meson
RUN git clone https://github.com/libfuse/libfuse.git
WORKDIR /user/lib/libfuse
RUN git checkout fuse-3.16.2 && mkdir build
WORKDIR /user/lib/libfuse/build
RUN meson .. && ninja && ninja install && pip install --upgrade pip wheel && \
    pip install git+https://github.com/inab/crypt4ghfs.git@v1.2.2 && \
    echo "user_allow_other" >> /etc/fuse.conf

WORKDIR /home
RUN useradd -u 1000 -m -s /bin/bash application && mkdir -p /home/application/encrypted_files && \
    chown application:application /home/application/encrypted_files && mkdir -p /home/application/clean_files && \
    chown application:application /home/application/clean_files
USER application
WORKDIR /home/application

ENV EGA_ENCRYPTED_FILES_MOUNTINGPOINT="/home/application/encrypted_files"
ENV EGA_CLEAN_FILES_MOUNTINGPOINT="/home/application/clean_files"
ENV USER_ID=1000
ENV GROUP_ID=1000 
ENV CRYP4GHFS_CONFIG="/tmp/fs.conf"
RUN echo "[DEFAULT]" > $CRYP4GHFS_CONFIG && \
    echo "rootdir=${EGA_ENCRYPTED_FILES_MOUNTINGPOINT}" >> $CRYP4GHFS_CONFIG && \
    echo "log_level=DEBUG" >> $CRYP4GHFS_CONFIG && \
    echo "include_crypt4gh_log=yes" >> $CRYP4GHFS_CONFIG && \
    echo "[CRYPT4GH]" >> $CRYP4GHFS_CONFIG && \
    echo "seckey=/tmp/ega_secret_key" >> $CRYP4GHFS_CONFIG && \
    echo "[FUSE]" >> $CRYP4GHFS_CONFIG && \
    echo "options=allow_other,default_permissions" >> $CRYP4GHFS_CONFIG

RUN chmod 600 $CRYP4GHFS_CONFIG
CMD sshfs -o reconnect -o BatchMode=yes -o IdentityFile="$USER_PRIVATE_KEY_FILE" \
    -o allow_other -o default_permissions -o uid="$USER_ID" -o gid="$GROUP_ID" -o StrictHostKeyChecking=no -o \
    UserKnownHostsFile=/dev/null "$EGA_USERNAME"@"$EGA_OUTBOX_ENDPOINT":./ "$EGA_ENCRYPTED_FILES_MOUNTINGPOINT" && crypt4ghfs -f --conf /tmp/fs.conf "$EGA_CLEAN_FILES_MOUNTINGPOINT"
