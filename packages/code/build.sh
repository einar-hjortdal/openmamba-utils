#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
spec="code.spec"
hash_file="$spec.hash"
repo_dir="$HOME/repo"

mkdir -p "$repo_dir"

# update spec
./code

# compute hash on the new spec file content
read -r new_hash _ < <(sha256sum "$spec")

# if the hash is the same as the last, no new version is available
if [[ -f $hash_file && $(cat "$hash_file") == "$new_hash" ]]; then
	exit 0
fi

cp "$spec" "$HOME/rpmbuild/SPECS/"
rpmbuild -ba "$HOME/rpmbuild/SPECS/$spec"

nvr=$(rpm -q --specfile "$spec" --qf '%{VERSION}-%{RELEASE}\n' | head -n1)

cp "/usr/src/RPM/RPMS/x86_64/code-$nvr".x86_64.rpm "$repo_dir/"
createrepo_c --update "$repo_dir"

# Record the hash last, a failed build is retried next time.
echo "$new_hash" >"$hash_file"
echo "built code $nvr"
