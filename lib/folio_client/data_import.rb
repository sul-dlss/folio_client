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
      sleep(5)

      upload_definition_id = response_hash.dig("fileDefinitions", 0, "uploadDefinitionId")
      job_execution_id = response_hash.dig("fileDefinitions", 0, "jobExecutionId")
      file_definition_id = response_hash.dig("fileDefinitions", 0, "id")

      upload_file_response_hash = client.post("/data-import/uploadDefinitions/#{upload_definition_id}/files/#{file_definition_id}", marc_binary(marc), content_type: "application/octet-stream")
      sleep(5)

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

    def default_wait_secs
      5
    end

    def default_timeout_secs
      5 * 60
    end

    def wait_with_timeout(wait_secs: default_wait_secs, timeout_secs: default_timeout_secs)
      Timeout.timeout(timeout_secs) do
        loop.with_index do |_, i|
          result = yield

          # If a 404, wait a bit longer before raising an error.
          check_not_found(result, i)
          return result if done_waiting?(result)

          sleep(wait_secs)
        end
      end
    rescue Timeout::Error
      Failure(:timeout)
    end

    def done_waiting?(result)
      result.success? || (result.failure? && result.failure == :error)
    end

    def check_not_found(result, index)
      return unless result.failure? && result.failure == :not_found && index > 2

      raise ResourceNotFound, "Id not found"
    end
  end
end
