# frozen_string_literal: true

class FolioClient
  # Lookup items in the Folio inventory
  class Inventory
    attr_accessor :client

    # @param client [FolioClient] the configured client
    def initialize(client)
      @client = client
    end

    # get instance HRID from barcode
    # @param barcode [String] barcode
    # @return [String,nil] instance HRID if present, otherwise nil.
    def fetch_hrid(barcode:)
      # find the instance UUID for this barcode
      response = client.connection.get("/search/instances", {query: "items.barcode==#{barcode}"}, client.http_get_headers)

      UnexpectedResponse.call(response) unless response.success?

      instance = JSON.parse(response.body)
      instance_uuid = instance.dig("instances", 0, "id")

      return nil unless instance_uuid

      # next lookup the instance given the instance_uuid so we can fetch the hrid
      response = client.connection.get("/inventory/instances/#{instance_uuid}", {}, client.http_get_headers)

      UnexpectedResponse.call(response) unless response.success?

      result = JSON.parse(response.body)
      result.dig("hrid")
    end

    # get instance external ID from HRID
    # @param hrid [String] instance HRID
    # @return [String,nil] instance external ID if present, otherwise nil.
    # @raise [ResourceNotFound, MultipleResourcesFound] if search does not return exactly 1 result
    def fetch_external_id(hrid:)
      response = client.connection.get("/search/instances", {query: "hrid==#{hrid}"}, client.http_get_headers)

      UnexpectedResponse.call(response) unless response.success?

      instance_response = JSON.parse(response.body)
      record_count = instance_response["totalRecords"]
      raise ResourceNotFound, "No matching instance found for #{hrid}" if instance_response["totalRecords"] == 0
      raise MultipleResourcesFound, "Expected 1 record for #{hrid}, but found #{record_count}" if record_count > 1

      instance_response.dig("instances", 0, "id")
    end

    # Retrieve basic information about a instance record.  Example usage: get the external ID and _version for update using
    #  optimistic locking when the HRID is available: `fetch_instance_info(hrid: 'a1234').slice('id', '_version')`
    #  (or vice versa if the external ID is available).
    # @param external_id [String] an external ID for the desired instance record
    # @param hrid [String] an instance HRID for the desired instance record
    # @return [Hash] information about the record.
    # @raise [ArgumentError] if the caller does not provide exactly one of external_id or hrid
    def fetch_instance_info(external_id: nil, hrid: nil)
      raise ArgumentError, "must pass exactly one of external_id or HRID" unless external_id.present? || hrid.present?
      raise ArgumentError, "must pass exactly one of external_id or HRID" if external_id.present? && hrid.present?

      external_id ||= fetch_external_id(hrid: hrid)
      response = client.connection.get("/inventory/instances/#{external_id}", {}, client.http_get_headers)

      UnexpectedResponse.call(response) unless response.success?

      JSON.parse(response.body)
    end

    # @param hrid [String] instance HRID
    # @param status_id [String] uuid for an instance status code
    # @return true if instance status matches the uuid param, false otherwise
    # @raise [ResourceNotFound] if search by instance HRID returns 0 results
    def has_instance_status?(hrid:, status_id:)
      # get the instance record and its statusId
      response = client.connection.get("/inventory/instances", {query: "hrid==#{hrid}"}, client.http_get_headers)

      UnexpectedResponse.call(response) unless response.success?

      instance = JSON.parse(response.body)
      raise ResourceNotFound, "No matching instance found for #{hrid}" if instance["totalRecords"] == 0

      instance_status_id = instance.dig("instances", 0, "statusId")

      return false unless instance_status_id

      return true if instance_status_id == status_id

      false
    end
  end
end
