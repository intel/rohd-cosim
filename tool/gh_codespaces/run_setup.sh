#!/bin/bash

# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# run_setup.sh
# GitHub Codespaces setup: Setting up the development environment.
#
# 2023 February 5
# Author: Chykon
#

set -euo pipefail

# Install Dart SDK.
tool/gh_codespaces/install_dart.sh

# Install Pub dependencies.
tool/gh_actions/install_dart_dependencies.sh

# Install Icarus Verilog.
tool/gh_actions/install_iverilog.sh

# Install Python.
tool/gh_actions/install_python.sh

# Install Python dependencies.
tool/gh_actions/install_python_dependencies.sh