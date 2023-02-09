#!/bin/bash

# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# install_python_dependencies.sh
# GitHub Actions step: Install software - pylint.
#
# 2023 February 9
# Author: Max Korbel <max.korbel@intel.com
#

set -euo pipefail

python3 -m pip install -r requirements_dev.txt
