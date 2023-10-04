#!/usr/bin/env ruby

require "bundler/setup"
require "folio_client"

marc_files = *ARGV

client =
  FolioClient.configure(
    url: ENV["OKAPI_URL"],
    login_params: {
      username: ENV["OKAPI_USER"],
      password: ENV["OKAPI_PASSWORD"]
    },
    okapi_headers: {
      "X-Okapi-Tenant": ENV["OKAPI_TENANT"],
      "User-Agent": "folio_client gem (testing)"
    }
  )

pp(client.fetch_marc_hash(instance_hrid: "a666"))

puts client.fetch_marc_xml(instance_hrid: "a666")
puts client.fetch_marc_xml(barcode: "20503330279")

records = marc_files.flat_map do |marc_file_path|
  MARC::Reader.new(marc_file_path).to_a
end

data_importer =
  client.data_import(
    records: records,
    job_profile_id: "e34d7b92-9b83-11eb-a8b3-0242ac130003",
    job_profile_name: "Default - Create instance and SRS MARC Bib"
  )

puts data_importer.wait_until_complete
puts data_importer.instance_hrids
