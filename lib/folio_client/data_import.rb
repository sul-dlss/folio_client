# frozen_string_literal: true

require "timeout"
require "date"
require "dry/monads"
require "marc"
require "stringio"

class FolioClient
  # Imports MARC records into FOLIO
  class DataImport
    include Dry::Monads[:result]

    attr_reader :job_execution_id

    # @param client [FolioClient] the configured client
    # @param record [MARC::Record] record to be imported
    # @param job_profile_id [String] job profile id to use for import
    # @param job_profile_name [String] job profile name to use for import
    def initialize(client, marc:, job_profile_id:, job_profile_name:)
      @client = client
      @marc = marc
      @job_profile_id = job_profile_id
      @job_profile_name = job_profile_name
    end

    def import
      response_hash = client.post("/data-import/uploadDefinitions", {fileDefinitions: [{name: marc_filename}]})
      upload_definition_id = response_hash.dig("fileDefinitions", 0, "uploadDefinitionId")
      @job_execution_id = response_hash.dig("fileDefinitions", 0, "jobExecutionId")
      file_definition_id = response_hash.dig("fileDefinitions", 0, "id")

      upload_file_response_hash = client.post("/data-import/uploadDefinitions/#{upload_definition_id}/files/#{file_definition_id}", marc_binary(marc), content_type: "application/octet-stream")

      client.post("/data-import/uploadDefinitions/#{upload_definition_id}/processFiles",
        {uploadDefinition: upload_file_response_hash, jobProfileInfo: {id: job_profile_id, name: job_profile_name, dataType: "MARC"}})
    end

    # @return [Dry::Monads::Result] Success if job is complete,
    # Failure(:pending) if job is still running,
    # Failure(:error) if job has errors
    # Failure(:not_found) if job is not found
    def job_status
      response_hash = client.get("/metadata-provider/jobSummary/#{job_execution_id}")

      return Failure(:error) if response_hash["totalErrors"].positive?
      return Failure(:pending) if response_hash.dig("sourceRecordSummary", "totalCreatedEntities").zero? && response_hash.dig("sourceRecordSummary", "totalUpdatedEntities").zero?
      Success()
    rescue ResourceNotFound
      # Checking the status immediately after starting the import may result in a 404.
      Failure(:not_found)
    end

    def wait(wait_secs: 1, timeout_secs: 5 * 60)
      Timeout.timeout(timeout_secs) do
        loop.with_index do |_, i|
          result = job_status

          # If a 404, wait a bit longer before raising an error.
          check_not_found(result, i)
          return result if done_waiting?(result)

          sleep(wait_secs)
        end
      end
    rescue Timeout::Error
      Failure(:timeout)
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

    def done_waiting?(result)
      result.success? || (result.failure? && result.failure == :error)
    end

    def check_not_found(result, index)
      return unless result.failure? && result.failure == :not_found && index > 2
      raise ResourceNotFound, "Job not found"
    end
  end
end
