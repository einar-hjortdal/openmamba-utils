#!/bin/bash
set -euo pipefail

name=pass-secret-service
repo_url=https://github.com/grimsteel/${name}
template=${name}.spec.template
output=${name}.spec
sources_dir=/usr/src/RPM/SOURCES

url=$(curl -sIL -o /dev/null -w '%{url_effective}' "$repo_url/releases/latest")
version=${url##*/v}

archive=$name-$version.tar.gz
archive_output=$sources_dir/$archive
if [[ ! -f ${archive_output} ]]; then
	curl -fL -o "$archive_output" "$repo_url/archive/v$version/$archive"
fi

{
	echo "%global pass_secret_service_version $version"
	echo
	cat "$template"
} >"$output"
