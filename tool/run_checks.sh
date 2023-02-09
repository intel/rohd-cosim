#!/bin/bash

# Copyright (C) 2022-2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# run_checks.sh
# Run project checks.
#
# 2022 October 11
# Author: Chykon
#

set -euo pipefail

form_bold=$(tput bold)
color_green=$(tput setaf 46)
color_red=$(tput setaf 196)
color_yellow=$(tput setaf 226)
text_reset=$(tput sgr0)

function print_step {
  printf '\n%s\n' "${color_yellow}Step: ${1}${text_reset}"
}

# Notification when the script fails
function trap_error {
  printf '\n%s\n\n' "${form_bold}${color_yellow}Result: ${color_red}FAILURE${text_reset}"
}

trap trap_error ERR

printf '\n%s\n' "${form_bold}${color_yellow}Running local checks...${text_reset}"

# Check software - Icarus Verilog
print_step 'Check software - Icarus Verilog'
printf '"which" output: '
if which iverilog; then
  echo 'Icarus Verilog found!'
else
  declare -r exit_code=${?}
  declare -r iverilog_recommended_version='11'
  echo 'Icarus Verilog not found: please install Icarus Verilog'\
    "(iverilog; recommended version: ${iverilog_recommended_version})!"
  exit ${exit_code}
fi

# Check software - Python3
print_step 'Check software - Python3'
printf '"which" output: '
if which python3; then
  echo 'Python3 found!'
else
  declare -r exit_code=${?}
  echo 'Python3 not found: please install Python3'
  exit ${exit_code}
fi

# Check software - cocotb
print_step 'Check software - cocotb'
printf '"which" output: '
if which cocotb-config; then
  echo 'cocotb found!'
else
  declare -r exit_code=${?}
  declare -r cocotb_recommended_version='1.7.2'
  echo 'cocotb not found: please install cocotb'\
    "(cocotb; recommended version: ${cocotb_recommended_version})!"
  exit ${exit_code}
fi

# Check software - pylint
print_step 'Check software - pylint'
printf '"which" output: '
if which pylint; then
  echo 'pylint found!'
else
  declare -r exit_code=${?}
  echo 'pylint not found: please install pylint'\
  exit ${exit_code}
fi

# Check software - black
print_step 'Check software - black'
printf '"which" output: '
if which black; then
  echo 'black found!'
else
  declare -r exit_code=${?}
  echo 'black not found: please install black'\
  exit ${exit_code}
fi

# Install dart dependencies
print_step 'Install dart dependencies'
tool/gh_actions/install_dart_dependencies.sh

# Verify dart formatting
print_step 'Verify dart formatting'
tool/gh_actions/verify_dart_formatting.sh

# Analyze dart source
print_step 'Analyze dart source'
tool/gh_actions/analyze_dart_source.sh

# Check project documentation
print_step 'Check project documentation'
tool/gh_actions/check_documentation.sh

# Verify python formatting
print_step 'Verify python formatting'
tool/gh_actions/verify_python_formatting.sh

# Analyze python source
print_step 'Analyze python source'
tool/gh_actions/analyze_python_source.sh

# Run project tests
print_step 'Run project tests'
tool/gh_actions/run_tests.sh

# Check folder - tmp_*
print_step 'Check folder - tmp_*'
tool/gh_actions/check_folder_tmp_test.sh

# Successful script execution notification
printf '\n%s\n\n' "${form_bold}${color_yellow}Result: ${color_green}SUCCESS${text_reset}"
