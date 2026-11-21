module main

import compress.gzip
import encoding.xml
import net.http
import strconv

const repo_url = 'https://packages.microsoft.com/yumrepos/edge-stable'
const repomd_url = repo_url + '/repodata/repomd.xml'
const package_name_prefix = 'microsoft-edge-'
const stable_package_name = package_name_prefix + 'stable'
const spec_path = './msedge.spec'

fn get_primary_metadata_url() !string {
	repomd := http.get(repomd_url)!
	document := xml.XMLDocument.from_string(repomd.body)!
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

struct PackageVersion {
	version string
	release string
}

struct PackageChecksum {
	checksum      string
	checksum_type string
}

struct PackageLocation {
	href string
}

struct Package {
	name     string
	version  PackageVersion
	checksum PackageChecksum
	location PackageLocation
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

fn (a Package) release_is_newer_than(b Package) !bool {
	a_release := strconv.parse_int(a.version.release, 64, 64)!
	b_release := strconv.parse_int(b.version.release, 64, 64)!
	return a_release > b_release
}

fn (a Package) is_newer_than(b Package) !bool {
	if !a.version_is_same_of(b) {
		return a.version_is_newer_than(b)!
	}
	return a.release_is_newer_than(b)
}

fn parse_package_name(node xml.XMLNode) !string {
	name_elements := node.get_elements_by_tag('name')
	if name_elements.len != 1 {
		return error('unexpected: 0 or more than 1 name in the same node')
	}

	n := name_elements[0]
	if n.children.len != 1 {
		return error('unexpected: 0 or more than 1 children in `name` node')
	}

	name := n.children[0]
	match name {
		string {
			return name
		}
		else {
			return error('unexpected name child type')
		}
	}
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

fn parse_package(node xml.XMLNode) !Package {
	return Package{
		name:     parse_package_name(node)!
		version:  parse_package_version(node)!
		checksum: parse_package_checksum(node)!
		location: parse_package_location(node)!
	}
}

fn find_latest_package(primary_metadata string) !Package {
	document := xml.XMLDocument.from_string(primary_metadata)!
	packages := document.get_elements_by_tag('package')
	if packages.len == 0 {
		return error('No packages exist')
	}

	mut latest := ?Package(none)
	for package in packages {
		parsed := parse_package(package)!
		if parsed.name != stable_package_name {
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

fn run() ! {
	primary_metadata_url := get_primary_metadata_url()!
	primary_metadata := get_primary_metadata(primary_metadata_url)!
	latest_package := find_latest_package(primary_metadata)!
	// TODO write package data in msedge.spec
}

fn main() {
	run() or { panic(err) }
}
