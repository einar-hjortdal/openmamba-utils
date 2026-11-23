module main

import os
//
import common

const repo_url = 'https://packages.microsoft.com/yumrepos/vscode'
const package_name = 'code'
const release_type_stable = package_name
const spec_template_path = './code.spec.template'
const spec_var_prefix = 'code_'
const spec_var_repo_url = spec_var_prefix + 'repo_url'
const spec_var_version = spec_var_prefix + 'version'
const spec_var_release = spec_var_prefix + 'release'
const spec_var_location = spec_var_prefix + 'location'
const spec_var_checksum_type = spec_var_prefix + 'checksum_type'
const spec_var_checksum = spec_var_prefix + 'checksum'
const spec_var_release_type = spec_var_prefix + 'release_type'

fn format_spec_variable(name string, value string) string {
	return '%global ${name} ${value}'
}

fn get_spec_path(release_type string) !string {
	match release_type {
		release_type_stable {} // good
		else {
			return error('invalid release type')
		}
	}
	return './${release_type}.spec'
}

fn update_spec(package common.Package) ! {
	spec_template_file := os.read_file(spec_template_path)!
	mut new_spec_file := []string{len: 0, cap: 8}
	new_spec_file << format_spec_variable(spec_var_repo_url, repo_url)
	new_spec_file << format_spec_variable(spec_var_checksum_type, package.checksum.checksum_type)
	new_spec_file << format_spec_variable(spec_var_checksum, package.checksum.checksum)
	new_spec_file << format_spec_variable(spec_var_location, package.location.href)
	new_spec_file << format_spec_variable(spec_var_version, package.version.version)
	new_spec_file << format_spec_variable(spec_var_release, package.version.release.split('.')[0]) // trim 'elx'
	new_spec_file << format_spec_variable(spec_var_release_type, release_type_stable)
	new_spec_file << spec_template_file
	new_spec_file_path := get_spec_path(release_type_stable)!
	os.write_file(new_spec_file_path, new_spec_file.join('\n'))!
}

fn run() ! {
	latest_package := common.get_latest_package(release_type_stable, repo_url)!
	update_spec(latest_package)!
}

fn main() {
	run() or { panic(err) }
}
