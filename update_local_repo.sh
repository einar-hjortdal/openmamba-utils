#!/bin/bash
set -euo pipefail

REPO_PATH="${HOME}/.local/share/rpmrepo"
RPM_TOPDIR="/usr/src/RPM"
RPMBUILD_SPECS="${RPM_TOPDIR}/SPECS"
RPMBUILD_RPMS="${RPM_TOPDIR}/RPMS"

sudo -v

repo_updated=false

for dir in ./packages/*/; do
	[[ -d "${dir}" ]] || continue

	# Find the .spec file in the package directory
	spec_file=$(find "${dir}" -maxdepth 1 -name "*.spec")
	if [[ -z "${spec_file}" ]]; then
		echo "Skipping ${dir}: No .spec file found."
		continue
	fi

	hash_file="${dir}spec.hash"
	read -r current_hash _ < <(sha256sum "${spec_file}")

	old_hash=""
	if [[ -f "${hash_file}" ]]; then
		old_hash=$(cat "${hash_file}")
	fi

	if [[ "${current_hash}" == "${old_hash}" ]]; then
		echo "No changes detected for $(basename "${dir}")"
		continue
	fi

	echo "Changes detected in spec file for ${dir}. Building package..."

	spec_name=$(basename "${spec_file}")

	sudo cp "${spec_file}" "${RPMBUILD_SPECS}/"
	sudo rpmbuild -ba "${RPMBUILD_SPECS}/${spec_name}"

	# Move the packages to the local repo
	sudo find "${RPMBUILD_RPMS}" -name "*.rpm" -exec mv -t "${REPO_PATH}" {} +
	sudo chown -R "$(id -u):$(id -g)" "${REPO_PATH}"

	# Update the hash file
	echo "${current_hash}" >"${hash_file}"
	repo_updated=true
done

if [[ "${repo_updated}" == true ]]; then
	echo "Updating repository metadata with createrepo..."
	createrepo --update "${REPO_PATH}"
else
	echo "All packages are up to date. No repository changes needed."
fi
