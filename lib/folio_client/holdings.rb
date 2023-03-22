# frozen_string_literal: true

class FolioClient
  # Manage holdings records in the Folio inventory
  # @deprecated - we no longer need to create Folio holdings records
  class Holdings
    attr_accessor :client, :instance_id

    # @param client [FolioClient] the configured client
    # @param instance_id [String] the UUID of the instance to which the holdings record belongs
    def initialize(client, instance_id:)
      @client = client
      @instance_id = instance_id
    end

    # create a holdings record for the instance
    # @param permanent_location_id [String] the UUID of the permanent location
    # @param holdings_type_id [String] the UUID of the holdings type
    # @deprecated - we no longer need to create Folio holdings records
    def create(holdings_type_id:, permanent_location_id:)
      warn "[DEPRECATION] SDR no longer needs to create FOLIO holdings records."
      client.post("/holdings-storage/holdings", {
        instanceId: instance_id,
        permanentLocationId: permanent_location_id,
        holdingsTypeId: holdings_type_id
      })
    end
  end
end
