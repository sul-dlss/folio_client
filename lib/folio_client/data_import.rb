# frozen_string_literal: true

require "date"
require "marc"
require "stringio"

class FolioClient
  # Imports MARC records into FOLIO
  class DataImport
    JOB_PROFILE_ATTRIBUTES = %w[id name description dataType].freeze

    # @param client [FolioClient] the configured client
    def initialize(client)
      @client = client
    end

    # @param records [Array<MARC::Record>] records to be imported
    # @param job_profile_id [String] job profile id to use for import
    # @param job_profile_name [String] job profile name to use for import
    # @return [JobStatus] a job status instance to get information about the data import job
    def import(records:, job_profile_id:, job_profile_name:)
      response_hash = client.post("/data-import/uploadDefinitions", {fileDefinitions: [{name: marc_filename}]})
      upload_definition_id = response_hash.dig("fileDefinitions", 0, "uploadDefinitionId")
      job_execution_id = response_hash.dig("fileDefinitions", 0, "jobExecutionId")
      file_definition_id = response_hash.dig("fileDefinitions", 0, "id")

      upload_file_response_hash = client.post(
        "/data-import/uploadDefinitions/#{upload_definition_id}/files/#{file_definition_id}",
        marc_binary(records),
        content_type: "application/octet-stream"
      )

      client.post(
        "/data-import/uploadDefinitions/#{upload_definition_id}/processFiles",
        {
          uploadDefinition: upload_file_response_hash,
          jobProfileInfo: {
            id: job_profile_id,
            name: job_profile_name,
            dataType: "MARC"
          }
        }
      )

      JobStatus.new(client, job_execution_id: job_execution_id)
    end

    # @return [Array<Hash<String,String>>] a list of job profile hashes
    def job_profiles
      client
        .get("/data-import-profiles/jobProfiles")
        .fetch("jobProfiles", [])
        .map { |profile| profile.slice(*JOB_PROFILE_ATTRIBUTES) }
    end

    private

    attr_reader :client, :job_profile_id, :job_profile_name

    def marc_filename
      @marc_filename ||= "#{DateTime.now.iso8601}.marc"
    end

    def marc_binary(records)
      StringIO.open do |io|
        MARC::Writer.new(io) do |writer|
          records.each { |record| writer.write(record) }
        end
        io.string
      end
    end
  end
end
