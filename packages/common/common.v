module common

import compress.gzip
import encoding.xml
import net.http

pub fn get_primary_metadata_url(repo_url string, repomd_url string) !string {
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

pub fn get_primary_metadata(primary_metadata_url string) !string {
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
