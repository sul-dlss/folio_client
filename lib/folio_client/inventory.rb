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
  end
end
