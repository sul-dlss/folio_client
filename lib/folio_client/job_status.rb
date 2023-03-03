# frozen_string_literal: true

require "timeout"
require "dry/monads"

class FolioClient
  # Wraps operations waiting for results from jobs
  class JobStatus
    include Dry::Monads[:result]

    attr_reader :job_execution_id

    # @param client [FolioClient] the configured client
    # @param job_execution_id [String] ID of the job to be checked on
    def initialize(client, job_execution_id:)
      @client = client
      @job_execution_id = job_execution_id
    end

    # @return [Dry::Monads::Result] Success if job is complete,
    # Failure(:pending) if job is still running,
    # Failure(:error) if job has errors
    # Failure(:not_found) if job is not found
    def status
      response_hash = client.get("/metadata-provider/jobSummary/#{job_execution_id}")

      return Failure(:error) if response_hash["totalErrors"].positive?
      return Failure(:pending) if response_hash.dig("sourceRecordSummary", "totalCreatedEntities").zero? && response_hash.dig("sourceRecordSummary", "totalUpdatedEntities").zero?

      Success()
    rescue ResourceNotFound
      # Checking the status immediately after starting the import may result in a 404.
      Failure(:not_found)
    end

    def wait_until_complete(wait_secs: 1, timeout_secs: 5 * 60)
      Timeout.timeout(timeout_secs) do
        loop.with_index do |_, i|
          result = status

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

    attr_reader :client

    def done_waiting?(result)
      result.success? || (result.failure? && result.failure == :error)
    end

    def check_not_found(result, index)
      return unless result.failure? && result.failure == :not_found && index > 2

      raise ResourceNotFound, "Job not found"
    end
  end
end
