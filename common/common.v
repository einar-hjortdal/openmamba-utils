module common

import compress.gzip
import encoding.xml
import net.http
import strconv

const target_arch = 'x86_64'
const repomd_path = '/repodata/repomd.xml'

fn get_primary_metadata_url(repo_url string) !string {
	repomd_url := repo_url + repomd_path
	repomd_file := http.get(repomd_url)!
	document := xml.XMLDocument.from_string(repomd_file.body)!
	primary_elements := document.get_elements_by_attribute('type', 'primary')
	if primary_elements.len != 1 {
		return error('malformed xml: 0 or more than 1 primary metadata in repomd.xml')
	}

	primary := primary_elements[0]
	location_elements := primary.get_elements_by_tag('location')
	if location_elements.len != 1 {
		return error('unexpected: 0 or more than 1 primary metadata location in repomd.xml')
	}

	primary_metadata_location := location_elements[0].attributes['href']
	if primary_metadata_location == '' {
		return error('unexpected: missin href in location tag in repomd.xml')
	}

	return repo_url + '/' + primary_metadata_location
}

fn get_primary_metadata(primary_metadata_url string) !string {
	response := http.get(primary_metadata_url)!
	content_type := response.header.get(.content_type) or {
		return error('Content-Type header missing from response')
	}

	if content_type != 'application/gzip' {
		return error('Content-Type header has unexpected value')
	}

	extracted := gzip.decompress(response.body.bytes())!
	return extracted.bytestr()
}

pub struct PackageVersion {
	pub     version string
	pub     release string
}

pub struct PackageChecksum {
	pub     checksum      string
	pub     checksum_type string
}

pub struct PackageLocation {
	pub     href string
}

pub struct Package {
	pub     name     string
	pub     arch     string
	pub     version  PackageVersion
	pub     checksum PackageChecksum
	pub     location PackageLocation
}

fn (a Package) parse_version_parts() ![]int {
	parts := a.version.version.split('.')
	mut res := []int{len: 0, cap: parts.len}
	for part in parts {
		res << strconv.parse_int(part, 64, 64)!
	}
	return res
}

fn (a Package) version_is_same_of(b Package) bool {
	return a.version.version == b.version.version
}

// we assume both packages use same versioning system
// must be called after Package.after version_is_same_of
fn (a Package) version_is_newer_than(b Package) !bool {
	a_parts := a.parse_version_parts()!
	b_parts := b.parse_version_parts()!
	if a_parts.len != b_parts.len {
		return error('version numbering system does not match across packages: ${a.version.version}, ${b.version.version}')
	}

	for i, a_int in a_parts {
		b_int := b_parts[i]
		if a_int > b_int {
			return true
		}
		if a_int == b_int {
			continue
		}
		return false
	}
	return error('unexpected package version, Package.version_is_newer_than must be called after Package.version_is_same_of')
}

// some packages (eg. code) has release strings that cannot be converted to integers such as `1683144671.el7`. To compare these releases, we compare the first segment which should be an integer.
// TODO tokenize properly, see rpmvercmp.c
fn (a Package) release_is_newer_than(b Package) !bool {
	a_release_parts := a.version.release.split('.')
	b_release_parts := b.version.release.split('.')

	// we assume same length of segments
	if a_release_parts.len != b_release_parts.len {
		return error('unexpected release segments lengths')
	}

	for i, a_part in a_release_parts {
		b_part := b_release_parts[i]
		// we assume segments are same type and no leading zeros
		if a_part > b_part {
			return true
		}

		if b_part > a_part {
			return false
		}
	}

	return a_release_parts.len > b_release_parts.len
}

pub fn (a Package) is_newer_than(b Package) !bool {
	if !a.version_is_same_of(b) {
		return a.version_is_newer_than(b)!
	}
	return a.release_is_newer_than(b)
}

fn parse_unique_string_child(node xml.XMLNode, tag string) !string {
	elements := node.get_elements_by_tag(tag)
	if elements.len != 1 {
		return error('unexpected: 0 or more than 1 tag with the same name in the same node')
	}

	element := elements[0]
	if element.children.len != 1 {
		return error('unexpected: 0 or more than 1 children in `${tag}` node')
	}

	child := element.children[0]
	match child {
		string {
			return child
		}
		else {
			return error('unexpected: child type is not string')
		}
	}
}

fn parse_package_name(node xml.XMLNode) !string {
	return parse_unique_string_child(node, 'name')
}

fn parse_package_arch(node xml.XMLNode) !string {
	return parse_unique_string_child(node, 'arch')
}

fn parse_package_version(node xml.XMLNode) !PackageVersion {
	version_elements := node.get_elements_by_tag('version')
	if version_elements.len != 1 {
		return error('unexpected: 0 or more than 1 version in the same node')
	}

	e := version_elements[0]
	version := e.attributes['ver'] or {
		return error('missing `ver` attribute from version node')
	}

	release := e.attributes['rel'] or {
		return error('missing `rel` attribute from version node')
	}

	return PackageVersion{
		version: version
		release: release
	}
}

fn parse_package_checksum(node xml.XMLNode) !PackageChecksum {
	checksum_elements := node.get_elements_by_tag('checksum')
	if checksum_elements.len != 1 {
		return error('unexpected: 0 or more than 1 checksum in the same node')
	}

	e := checksum_elements[0]
	checksum_type := e.attributes['type'] or {
		return error('missing `type` attribute from checksum node')
	}

	if e.children.len != 1 {
		return error('unexpected: 0 or more than 1 children in checksum node')
	}

	checksum := e.children[0]
	match checksum {
		string {
			return PackageChecksum{
				checksum_type: checksum_type
				checksum:      checksum
			}
		}
		else {
			return error('unexpected checksum child type')
		}
	}
}

fn parse_package_location(node xml.XMLNode) !PackageLocation {
	location_elements := node.get_elements_by_tag('location')
	if location_elements.len != 1 {
		return error('unexpected: 0 or more than 1 location in the same node')
	}

	location := location_elements[0]
	href := location.attributes['href'] or {
		return error('missing `href` attribute from location node')
	}

	return PackageLocation{
		href: href
	}
}

fn find_latest_package(package_name string, primary_metadata string) !Package {
	document := xml.XMLDocument.from_string(primary_metadata)!
	package_nodes := document.get_elements_by_tag('package')
	if package_nodes.len == 0 {
		return error('No packages exist')
	}

	mut latest := ?Package(none)
	for node in package_nodes {
		parsed := Package{
			name:     parse_package_name(node)!
			arch:     parse_package_arch(node)!
			version:  parse_package_version(node)!
			checksum: parse_package_checksum(node)!
			location: parse_package_location(node)!
		}

		if parsed.name != package_name || parsed.arch != target_arch {
			continue
		}

		current := latest or {
			latest = parsed
			continue
		}

		parsed_is_newer := parsed.is_newer_than(current)!
		if parsed_is_newer {
			latest = parsed
		}
	}

	found := latest or {
		return error('no valid package found')
	}
	return found
}

pub fn get_latest_package(package_name string, repo_url string) !Package {
	primary_metadata_url := get_primary_metadata_url(repo_url)!
	primary_metadata := get_primary_metadata(primary_metadata_url)!
	return find_latest_package(package_name, primary_metadata)
}

pub fn format_spec_variable(name string, value string) string {
	return '%global ${name} ${value}'
}