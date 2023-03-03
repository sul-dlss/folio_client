# frozen_string_literal: true

RSpec.describe FolioClient::JobStatus do
  include Dry::Monads[:result]

  let(:job_status) { described_class.new(client, job_execution_id: job_execution_id) }
  let(:client) do
    FolioClient.configure(
      url: url,
      login_params: {username: "username", password: "password"},
      okapi_headers: {some_bogus_headers: "here"}
    )
  end
  let(:job_execution_id) { "4ba4f4ab" }
  let(:token) { "a_long_silly_token" }
  let(:url) { "https://folio.example.org" }

  before do
    stub_request(:post, "#{url}/authn/login")
      .to_return(status: 200, body: "{\"okapiToken\" : \"#{token}\"}")
    allow(DateTime).to receive(:now).and_return(DateTime.parse("2023-03-01T11:17:25-05:00"))
  end

  describe "#job_execution_id" do
    it "returns the job execution ID" do
      expect(job_status.job_execution_id).to eq(job_execution_id)
    end
  end

  describe "#status" do
    before do
      stub_request(:get, "#{url}/metadata-provider/jobSummary/#{job_execution_id}")
        .with(
          headers: {
            "X-Okapi-Token" => "a_long_silly_token"
          }
        )
        .to_return(status: status, body: status_response_body.to_json, headers: {})
    end

    let(:status) { 200 }

    context "when job is pending" do
      let(:status_response_body) do
        {
          jobExecutionId: job_execution_id,
          totalErrors: 0,
          sourceRecordSummary: {
            totalCreatedEntities: 0,
            totalUpdatedEntities: 0,
            totalDiscardedEntities: 0,
            totalErrors: 0
          }
        }
      end

      it "returns Failure(:pending)" do
        expect(job_status.status).to eq(Failure(:pending))
      end
    end

    context "when job error" do
      let(:status_response_body) do
        {
          jobExecutionId: job_execution_id,
          totalErrors: 1,
          sourceRecordSummary: {
            totalCreatedEntities: 0,
            totalUpdatedEntities: 0,
            totalDiscardedEntities: 0,
            totalErrors: 1
          }
        }
      end

      it "returns Failure(:error)" do
        expect(job_status.status).to eq(Failure(:error))
      end
    end

    context "when job is complete" do
      let(:status_response_body) do
        {
          jobExecutionId: job_execution_id,
          totalErrors: 0,
          sourceRecordSummary: {
            totalCreatedEntities: 1,
            totalUpdatedEntities: 0,
            totalDiscardedEntities: 0,
            totalErrors: 0
          }
        }
      end

      it "returns Success" do
        expect(job_status.status).to eq(Success())
      end
    end

    context "when job is not found" do
      let(:status) { 404 }
      let(:status_response_body) { "JobSummary for jobExecutionId: '#{job_execution_id}' was not found" }

      it "returns Failure(:not_found)" do
        expect(job_status.status).to eq(Failure(:not_found))
      end
    end
  end

  describe "#wait_until_complete" do
    context "when job is complete" do
      before do
        allow(job_status).to receive(:status).and_return(Failure(:not_found), Failure(:pending), Success())
      end

      it "returns Success" do
        expect(job_status.wait_until_complete(wait_secs: 0.1)).to eq(Success())
        expect(job_status).to have_received(:status).exactly(3).times
      end
    end

    context "when job is error" do
      before do
        allow(job_status).to receive(:status).and_return(Failure(:pending), Failure(:pending), Failure(:error))
      end

      it "returns Failure(:error)" do
        expect(job_status.wait_until_complete(wait_secs: 0.1)).to eq(Failure(:error))
        expect(job_status).to have_received(:status).exactly(3).times
      end
    end

    context "when too many 404s" do
      before do
        allow(job_status).to receive(:status).and_return(Failure(:not_found))
      end

      it "raises ResourceNotFound" do
        expect { job_status.wait_until_complete(wait_secs: 0.1) }.to raise_error(FolioClient::ResourceNotFound)
        expect(job_status).to have_received(:status).exactly(4).times
      end
    end

    context "when timeout" do
      before do
        allow(job_status).to receive(:status).and_return(Failure(:pending))
      end

      it "returns Failure(:timeout)" do
        expect(job_status.wait_until_complete(wait_secs: 0.5, timeout_secs: 0.25)).to eq(Failure(:timeout))
      end
    end
  end
end
