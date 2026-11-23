#!/bin/bash
set -euo pipefail

if [[ ! -f "./main" ]]; then
	v . -o main
fi

./main
