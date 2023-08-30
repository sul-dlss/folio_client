# frozen_string_literal: true

class FolioClient
  # Lookup records in Folio Source Storage
  class SourceStorage
    attr_accessor :client

    # @param client [FolioClient] the configured client
    def initialize(client)
      @client = client
    end

    # get marc bib data from folio given an instance HRID
    # @param instance_hrid [String] the key to use for MARC lookup
    # @return [Hash] hash representation of the MARC. should be usable by MARC::Record.new_from_hash (from ruby-marc gem)
    # @raise [ResourceNotFound]
    # @raise [MultipleResourcesFound]
    def fetch_marc_hash(instance_hrid:)
      response = client.connection.get("/source-storage/source-records", {instanceHrid: instance_hrid}, client.http_get_headers)
      UnexpectedResponse.call(response) unless response.success?
      response_hash = JSON.parse(response.body)

      record_count = response_hash["totalRecords"]
      raise ResourceNotFound, "No records found for #{instance_hrid}" if record_count.zero?
      raise MultipleResourcesFound, "Expected 1 record for #{instance_hrid}, but found #{record_count}" if record_count > 1

      response_hash["sourceRecords"].first["parsedRecord"]["content"]
    end
  end
end
