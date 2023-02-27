# frozen_string_literal: true

class FolioClient
  # Lookup items in the Folio inventory
  class Inventory
    attr_accessor :client

    # @param client [FolioClient] the configured client
    def initialize(client)
      @client = client
    end

    # @param barcode [String] barcode to search by to fetch the HRID
    # @return [String,nil] HRID if present, otherwise nil.
    def fetch_hrid(barcode:)
      # find the instance UUID for this barcode
      instance = client.get("/search/instances", {query: "items.barcode==#{barcode}"})
      instance_uuid = instance.dig("instances", 0, "id")

      return nil unless instance_uuid

      # next lookup the instance given the instance_uuid so we can fetch the hrid
      result = client.get("/inventory/instances/#{instance_uuid}")
      result.dig("hrid")
    end

    # @param hrid [String] folio instance HRID
    # @param status_id [String] uuid for an instance status code
    # @raise [ResourceNotFound] if search by hrid returns 0 results
    def has_instance_status?(hrid:, status_id:)
      # get the instance record and its statusId
      instance = client.get("/inventory/instances", {query: "hrid==#{hrid}"})
      raise ResourceNotFound, "No matching instance found for #{hrid}" if instance["totalRecords"] == 0

      instance_status_id = instance.dig("instances", 0, "statusId")

      return false unless instance_status_id

      return true if instance_status_id == status_id

      false
    end
  end
end
