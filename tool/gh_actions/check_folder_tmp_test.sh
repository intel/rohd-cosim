#!/bin/bash

# Copyright (C) 2022-2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# check_folder_tmp_test.sh
# GitHub Actions step: Check folder - tmp_*.
#
# 2022 October 12
# Author: Chykon
#

set -euo pipefail

declare -r folder_prefix='tmp_'

# The "tmp_*" folders after performing the tests should be empty.
for folder_name in $(find . -type d -name "${folder_prefix}*"); do
  if [ -d "${folder_name}" ]; then
    output=$(find ${folder_name} | wc --lines | tee)
    if [ "${output}" -eq 1 ]; then
      echo "Success: directory \"${folder_name}\" is empty!"
    else
      echo "Failure: directory \"${folder_name}\" is not empty!"
      exit 1
    fi
  else
    echo "Failure: directory \"${folder_name}\" not found!"
    exit 1
  fi
done
