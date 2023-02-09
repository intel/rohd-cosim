#!/bin/bash

# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# install_python.sh
# GitHub Actions step: Install software - Python.
#
# 2023 February 9
# Author: Max Korbel <max.korbel@intel.com
#

set -euo pipefail

sudo apt-get update
sudo apt-get install --yes python3 python3-pip
