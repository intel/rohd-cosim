#!/bin/bash

# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# install_verilator.sh
# GitHub Actions step: Install software - Verilator.
#
# 2025 January 23
# Author: Max Korbel <max.korbel@intel.com>

set -euo pipefail

# Verilator version to install.
VERILATOR_VERSION="v5.022"

echo "Installing Verilator $VERILATOR_VERSION"

# see instructions here:
# https://verilator.org/guide/latest/install.html

sudo apt-get install --yes git help2man perl python3 make
sudo apt-get install --yes g++  # Alternatively, clang
sudo apt-get install --yes libgz  # Non-Ubuntu (ignore if gives error)
sudo apt-get install --yes libfl2  # Ubuntu only (ignore if gives error)
sudo apt-get install --yes libfl-dev  # Ubuntu only (ignore if gives error)
sudo apt-get install --yes zlibc zlib1g zlib1g-dev  # Ubuntu only (ignore if gives error)

sudo apt-get install --yes ccache  # If present at build, needed for run
sudo apt-get install --yes mold  # If present at build, needed for run
sudo apt-get install --yes libgoogle-perftools-dev numactl

sudo apt-get install --yes perl-doc

sudo apt-get install --yes git autoconf flex bison

# Clone the Verilator repository.
git clone https://github.com/verilator/verilator
cd verilator

git checkout $VERILATOR_VERSION

autoconf

# install to a default global location
unset VERILATOR_ROOT
./configure

make -j `nproc`
make install