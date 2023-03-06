# frozen_string_literal: true

require "date"
require "marc"
require "stringio"

class FolioClient
  # Imports MARC records into FOLIO
  class DataImport
    # @param client [FolioClient] the configured client
    def initialize(client)
      @client = client
    end

    # @param record [MARC::Record] record to be imported
    # @param job_profile_id [String] job profile id to use for import
    # @param job_profile_name [String] job profile name to use for import
    def import(marc:, job_profile_id:, job_profile_name:)
      response_hash = client.post("/data-import/uploadDefinitions", {fileDefinitions: [{name: marc_filename}]})
      upload_definition_id = response_hash.dig("fileDefinitions", 0, "uploadDefinitionId")
      job_execution_id = response_hash.dig("fileDefinitions", 0, "jobExecutionId")
      file_definition_id = response_hash.dig("fileDefinitions", 0, "id")

      upload_file_response_hash = client.post("/data-import/uploadDefinitions/#{upload_definition_id}/files/#{file_definition_id}", marc_binary(marc), content_type: "application/octet-stream")

      client.post("/data-import/uploadDefinitions/#{upload_definition_id}/processFiles",
        {uploadDefinition: upload_file_response_hash, jobProfileInfo: {id: job_profile_id, name: job_profile_name, dataType: "MARC"}})
      JobStatus.new(client, job_execution_id: job_execution_id)
    end

    private

    attr_reader :client, :marc, :job_profile_id, :job_profile_name

    def marc_filename
      @marc_filename ||= "#{DateTime.now.iso8601}.marc"
    end

    def marc_binary(marc)
      StringIO.open do |io|
        MARC::Writer.new(io) do |writer|
          writer.write(marc)
        end
        io.string
      end
    end
  end
end
