# frozen_string_literal: true

class FolioClient
  # Edit MARC JSON records in Folio
  class RecordsEditor
    # Given an HRID, retrieves the associated MARC JSON, yields it to the caller as a hash,
    # and attempts to re-save it, using optimistic locking to prevent accidental overwrite,
    # in case another user or process has updated the record in the time between retrieval and
    # attempted save.
    # @param hrid [String] the HRID of the MARC record to be edited and saved
    # @yieldparam record_json [Hash] a hash representation of the MARC JSON for the
    #  HRID; the updated hash will be saved when control is returned from the block.
    # @note in limited manual testing, optimistic locking behaved like so when two edit attempts collided:
    #   * One updating client would eventually raise a timeout.  This updating client would actually write successfully, and version the record.
    #   * The other updating client would raise a StandardError, with a message like 'duplicate key value violates unique
    #     constraint \"idx_records_matched_id_gen\"'.
    #     This client would fail to write.
    #   * As opposed to the expected behavior of the "winner" getting a 200 ok response, and the "loser" getting a 409 conflict response.
    # @todo If this is a problem in practice, see if it's possible to have Folio respond in a more standard way; or, workaround with error handling.
    def edit_marc_json(hrid:)
      instance_info = client.fetch_instance_info(hrid: hrid)

      version = instance_info['_version']
      external_id = instance_info['id']

      record_json = client.get('/records-editor/records', { externalId: external_id })

      parsed_record_id = record_json['parsedRecordId']
      # setting this field on the JSON we send back is what will allow optimistic locking to catch stale updates
      record_json['relatedRecordVersion'] = version
      record_json['_actionType'] = 'edit'

      yield record_json

      client.put("/records-editor/records/#{parsed_record_id}", record_json)
    end

    private

    def client
      FolioClient.instance
    end
  end
end
