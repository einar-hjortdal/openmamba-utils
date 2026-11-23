# Openmamba-utils

Each directory in `packages` should contain `build.sh` that creates a `.spec` file.

- [install_local_repo.sh](./install_local_repo.sh) creates a repo dir in the home directory and installs it.
- [compile.sh](./compile.sh) compiles all the binaries needed by running `build.sh` in each dir in [packages](./packages/).
- [update_spec_files.sh](./update_spec_files.sh) updates all the spec files by running `update.sh` in each dir in [packages](./packages/).
- [update_local_repo.sh](./update_local_repo.sh) checks for any changes and updates the local repository.
