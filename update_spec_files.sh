#!/bin/bash
set -euo pipefail

for dir in ./packages/*/; do
	[[ -d "${dir}" ]] || continue # Ensure it's actually a directory

	build_script="${dir}build.sh"
	if [[ -f "${dir}build.sh" ]]; then # Check if build.sh exists and is a file
		echo "Running ${build_script}"
		# Use a subshell (parentheses) so 'cd' doesn't affect the outer loop's path
		(
			cd "${dir}"
			./build.sh
		)
	else
		echo "No ${build_script} found"
	fi
done
