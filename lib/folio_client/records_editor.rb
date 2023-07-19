# frozen_string_literal: true

class FolioClient
  class RecordsEditor
    attr_accessor :client

    # @param client [FolioClient] the configured client
    def initialize(client)
      @client = client
    end

    # Given an HRID, retrieves the associated MARC JSON, yields it to the caller as a hash,
    # and attempts to re-save it, using optimistic locking to prevent accidental overwrite,
    # in case another user or process has updated the record in the time between retrieval and
    # attempted save.
    # @param hrid [String] the HRID of the MARC record to be edited and saved
    # @yieldparam record_json [Hash] a hash representation of the MARC JSON for the
    #  HRID; the updated hash will be saved when control is returned from the block.
    # @note in limited manual testing, optimistic locking behaved like so when two edit attempts collided:
    #   * One updating client would eventually raise a timeout.  This updating client would actually write successfully, and version the record.
    #   * The other updating client would raise a StandardError, with a message like 'duplicate key value violates unique constraint \"idx_records_matched_id_gen\"'.
    #     This client would fail to write.
    #   * As opposed to the expected behavior of the "winner" getting a 200 ok response, and the "loser" getting a 409 conflict response.
    # @todo If this is a problem in practice, see if it's possible to have Folio respond in a more standard way; or, workaround with error handling.
    def edit_marc_json(hrid:)
      retry_srs_retrieval do 
        instance_info = client.fetch_instance_info(hrid: hrid)

        version = instance_info["_version"]
        external_id = instance_info["id"]

        record_json = client.get("/records-editor/records", {externalId: external_id})
        # if recordState is not ACTUAL (e.g. ERROR), retry
        raise StandardError unless record_json["updateInfo"]["recordState"] == "ACTUAL"
        
        parsed_record_id = record_json["parsedRecordId"]
        record_json["relatedRecordVersion"] = version # setting this field on the JSON we send back is what will allow optimistic locking to catch stale updates

        yield record_json

        client.put("/records-editor/records/#{parsed_record_id}", record_json)
      end
    end

    MAX_TRIES = 5

    def retry_srs_retrieval
      @try_count ||= 0
      yield
    rescue StandardError
      @try_count += 1
      if @try_count <= MAX_TRIES
        sleep 10
        retry
      else 
        raise StandardError, "Source record does not have status 'ACTUAL' after #{MAX_TRIES} tries"
      end
    end
  end
end
