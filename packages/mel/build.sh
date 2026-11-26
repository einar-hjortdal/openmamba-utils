#!/bin/bash
set -euo pipefail

name=mel
repo_url=https://github.com/x017/${name}
template=${name}.spec.template
output=${name}.spec
sources_dir=/usr/src/RPM/SOURCES

# latest commit on the default branch
read -r commit _ < <(git ls-remote "$repo_url" HEAD)

# commit date, from a shallow bare clone in a temp dir
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone --quiet --bare --depth 1 "$repo_url" "$tmp/repo"
dates=$(TZ=UTC git -C "$tmp/repo" log --format=%cd --date=format-local:%Y%m%d)
commit_date=$(git -C "$tmp/repo" log -1 --format=%cd --date=format:%Y%m%d)
commit_count=$(grep -c "^${commit_date}$" <<<"$dates")

archive=$name-$commit.tar.gz
archive_output=$sources_dir/$archive
if [[ ! -f $archive_output ]]; then
	curl -fL -o "$archive_output" "$repo_url/archive/$commit/$archive"
fi

{
	echo "%global commit $commit"
	echo "%global commit_date $commit_date"
	echo "%global commit_count $commit_count"
	echo
	cat "$template"
} >"$output"
