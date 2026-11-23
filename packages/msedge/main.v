module main

import os
//
import common

const repo_url = 'https://packages.microsoft.com/yumrepos/edge-stable'
const package_name = 'microsoft-edge-stable'
const spec_template_path = './${package_name}.spec.template'
const spec_path = './${package_name}.spec'

const spec_var_prefix = 'edge_'
const spec_var_repo_url = spec_var_prefix + 'repo_url'
const spec_var_version = spec_var_prefix + 'version'
const spec_var_release = spec_var_prefix + 'release'
const spec_var_location = spec_var_prefix + 'location'
const spec_var_checksum_type = spec_var_prefix + 'checksum_type'
const spec_var_checksum = spec_var_prefix + 'checksum'
const spec_var_package_name = spec_var_prefix + 'package_name'

fn update_spec(package common.Package) ! {
	spec_template_file := os.read_file(spec_template_path)!
	new_spec_file := [
		common.format_spec_variable(spec_var_repo_url, repo_url),
		common.format_spec_variable(spec_var_checksum_type, package.checksum.checksum_type),
		common.format_spec_variable(spec_var_checksum, package.checksum.checksum),
		common.format_spec_variable(spec_var_location, package.location.href),
		common.format_spec_variable(spec_var_version, package.version.version),
		common.format_spec_variable(spec_var_release, package.version.release),
		common.format_spec_variable(spec_var_package_name, package_name),
		spec_template_file,
	]
	os.write_file(spec_path, new_spec_file.join('\n'))!
}

fn run() ! {
	latest_package := common.get_latest_package(package_name, repo_url)!
	update_spec(latest_package)!
}

fn main() {
	run() or { panic(err) }
}
