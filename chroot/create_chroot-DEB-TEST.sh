#!/bin/bash

if [ $(id -u) -ne 0 ]; then
  echo -e "\nPlease start the script as a root or sudo!\n"
  exit 1
else
  if [ $# -ge 4 ]; then

# --ARGUMENTS-- (example)

# CHROOT_GADGETRON_INSTALL_PREFIX:    /usr/local/gadgetron
# CHROOT_GADGETRON_BINARY_DIR:        /home/ubuntu/gadgetron/build
# CHROOT_GIT_SHA1_HASH:               f4d7a9189fd21b07e482d28ecb8b07e589f81f9e
# CHROOT_LIBRARY_PATHS:               /usr/local/lib:/usr/lib/x86_64-linux-gnu
# PACKAGES_PATH:                      /home/ubuntu/packages
    CHROOT_GADGETRON_INSTALL_PREFIX=${1}
    echo CHROOT_GADGETRON_INSTALL_PREFIX: ${CHROOT_GADGETRON_INSTALL_PREFIX}
    CHROOT_GADGETRON_BINARY_DIR=${2}
    echo CHROOT_GADGETRON_BINARY_DIR: ${CHROOT_GADGETRON_BINARY_DIR}
    CHROOT_GIT_SHA1_HASH=${3}
    echo CHROOT_GIT_SHA1_HASH: ${CHROOT_GIT_SHA1_HASH}
    CHROOT_LIBRARY_PATHS=${4}
    echo CHROOT_LIBRARY_PATHS: ${CHROOT_LIBRARY_PATHS}
 
    # Add LIBRARY_PATHS to LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${CHROOT_LIBRARY_PATHS}
    export LC_ALL=C
    echo "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH}"

    rm -rf ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root
    mkdir -p ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root
    touch ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/source-manifest.txt
    echo "gadgetron    ${CHROOT_GIT_SHA1_HASH}" > ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/source-manifest.txt
    mkdir -p ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron

    if [ $# -eq 5 ]; then
      PACKAGES_PATH=${5}
      echo PACKAGES_PATH: ${PACKAGES_PATH}
      mkdir -p ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron/debian/
      cp ${PACKAGES_PATH}/*.deb ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron/debian
    fi

    mkdir -p ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-backups

    apt-get install debootstrap -y

    debootstrap --variant=buildd --arch amd64 trusty ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron http://gb.archive.ubuntu.com/ubuntu/

    chroot ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron apt-get --yes install software-properties-common

    # Update sources.list files with the local folder
    if [ $# -eq 5 ]; then
      cd ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron/debian
      dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
      sed -i '1s;^;deb file:/debian ./\n;' ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron/etc/apt/sources.list
    fi

    # Update sources.list files with the AWS s3 bucket
    if [ $# -eq 4 ]; then
      chroot ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron add-apt-repository "deb http://gadgetronubuntu.s3.amazonaws.com trusty main"
    fi

    chroot ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron add-apt-repository "deb http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ trusty restricted main multiverse universe"
    chroot ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron add-apt-repository "deb http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ trusty-updates universe restricted multiverse main"
    chroot ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron add-apt-repository "deb http://security.ubuntu.com/ubuntu trusty-security main universe"
    chroot ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron add-apt-repository "deb http://gb.archive.ubuntu.com/ubuntu trusty main"

    chroot ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron apt-get update
    chroot ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron apt-get --yes install sudo build-essential python-dev python-twisted python-psutil python-numpy python-h5py gdebi-core libxml2-dev

    if [ $# -eq 4 ]; then
      chroot ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron apt-get --yes --force-yes install libopenblas-base ismrmrd siemens-to-ismrmrd gadgetron
    fi

    if [ $# -eq 5 ]; then
      for package in ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron/debian/*.deb;
      do chroot ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron gdebi "/debian/$(basename ${package})";
      done
    fi

    cp -n ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron${CHROOT_GADGETRON_INSTALL_PREFIX}/config/gadgetron.xml.example ${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-root/gadgetron${CHROOT_GADGETRON_INSTALL_PREFIX}/config/gadgetron.xml

    TAR_FILE_NAME=gadgetron-`date '+%Y%m%d-%H%M'`-${CHROOT_GIT_SHA1_HASH:0:8}

    tar -zcf "${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-backups/${TAR_FILE_NAME}.tar.gz" --directory "${CHROOT_GADGETRON_BINARY_DIR}/chroot" --exclude=./chroot-root/gadgetron/dev --exclude=./chroot-root/gadgetron/sys --exclude=./chroot-root/gadgetron/proc --exclude=./chroot-root/gadgetron/root ./chroot-root
    chmod 666 "${CHROOT_GADGETRON_BINARY_DIR}/chroot/chroot-backups/${TAR_FILE_NAME}.tar.gz"
    exit 0
  else
    echo -e "\nUsage:  $0 (gadgetron install prefix) (gadgetron binary dir) (GADGETRON_GIT_SHA1_HASH) (LIBRARY_PATHS) optional:(PACKAGES_PATH)\n"
    exit 1
  fi
fi
