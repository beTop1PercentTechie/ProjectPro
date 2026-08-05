#!/usr/bin/env bash
# colors.sh - Terminal color codes used across LSAMS output.
# Disabled automatically when stdout is not a terminal or NO_COLOR is set.

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    readonly C_RESET='\033[0m'
    readonly C_BOLD='\033[1m'
    readonly C_RED='\033[0;31m'
    readonly C_GREEN='\033[0;32m'
    readonly C_YELLOW='\033[0;33m'
    readonly C_BLUE='\033[0;34m'
    readonly C_MAGENTA='\033[0;35m'
    readonly C_CYAN='\033[0;36m'
    readonly C_GRAY='\033[0;90m'
else
    readonly C_RESET='' C_BOLD='' C_RED='' C_GREEN='' C_YELLOW=''
    readonly C_BLUE='' C_MAGENTA='' C_CYAN='' C_GRAY=''
fi
