#!/bin/bash

# Copyright (C) 2022-2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# verify_python_formatting.sh
# GitHub Actions step: Verify python formatting.
#
# 2023 February 9
# Author: Max Korbel <max.korbel@intel.com>

set -euo pipefail

if black --check python/; then
  echo 'Format check passed!'
else
  declare -r exit_code=${?}
  echo 'Format check failed: please format your code (use "black python/")!'
  exit ${exit_code}
fi
