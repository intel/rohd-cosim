#!/bin/bash

# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# analyze_python_source.sh
# GitHub Actions step: Analyze project source.
#
# 2022 October 9
# Author: Max Korbel <max.korbel@intel.com>
#

set -euo pipefail

pylint --fail-under 10 python/