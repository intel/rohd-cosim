#!/bin/bash

# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# install_cocotb.sh
# GitHub Actions step: Install software - cocotb.
#
# 2023 February 9
# Author: Max Korbel <max.korbel@intel.com
#

set -euo pipefail

python3 -m pip install cocotb==1.7.2