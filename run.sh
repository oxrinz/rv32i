#!/bin/bash

set -e

DEBUG=${DEBUG:-0}

sh sh/compiler.sh
sh sh/assembler.sh
sh sh/sim.sh