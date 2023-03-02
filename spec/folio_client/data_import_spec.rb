# frozen_string_literal: true

RSpec.describe FolioClient::DataImport do
  include Dry::Monads[:result]

  subject(:data_import) { described_class.new(client, marc: marc, job_profile_id: job_profile_id, job_profile_name: job_profile_name) }

  let(:args) { {url: url, login_params: login_params, okapi_headers: okapi_headers} }
  let(:url) { "https://folio.example.org" }
  let(:login_params) { {username: "username", password: "password"} }
  let(:okapi_headers) { {some_bogus_headers: "here"} }
  let(:token) { "a_long_silly_token" }
  let(:client) { FolioClient.configure(**args) }
  let(:marc) do
    MARC::Record.new.tap do |record|
      record << MARC::DataField.new("245", "0", " ", ["a", "Folio 21: a bibliography of the Folio Society 1947-1967"])
    end
  end
  let(:job_profile_id) { "ae0a94d0" }
  let(:job_profile_name) { "ETDs" }
  let(:job_execution_id) { "4ba4f4ab" }

  before do
    stub_request(:post, "#{url}/authn/login")
      .to_return(status: 200, body: "{\"okapiToken\" : \"#{token}\"}")
    allow(DateTime).to receive(:now).and_return(DateTime.parse("2023-03-01T11:17:25-05:00"))
  end

  describe "#import" do
    let(:upload_definition_request_body) do
      {
        fileDefinitions:
        [
          {name: "2023-03-01T11:17:25-05:00.marc"}
        ]
      }
    end

    let(:upload_definition_response_body) do
      {
        id: "d39546ed-622b-4e09-92ca-210535ff7ab4",
        metaJobExecutionId: "4ba4f4ab-d3fd-45b1-b73f-f3f0bcff17fe",
        status: "NEW",
        createDate: "2023-02-14T13:16:19.708+00:00",
        fileDefinitions: [
          {
            id: "181f6315-aa98-4b4d-ab1f-3c7f9df524b1",
            name: "2023-03-01T11:17:25-05:00.marc",
            status: "NEW",
            jobExecutionId: job_execution_id,
            uploadDefinitionId: "d39546ed-622b-4e09-92ca-210535ff7ab4",
            createDate: "2023-02-14T13:16:19.708+00:00"
          }
        ],
        metadata: {
          createdDate: "2023-02-14T13:16:19.474+00:00",
          createdByUserId: "297649ab-3f9e-5ece-91a3-25cf700062ae",
          updatedDate: "2023-02-14T13:16:19.474+00:00",
          updatedByUserId: "297649ab-3f9e-5ece-91a3-25cf700062ae"
        }
      }
    end

    let(:upload_file_response_body) do
      {
        id: "d39546ed-622b-4e09-92ca-210535ff7ab4",
        metaJobExecutionId: "4ba4f4ab-d3fd-45b1-b73f-f3f0bcff17fe",
        status: "LOADED",
        createDate: "2023-02-14T13:16:19.708+00:00",
        fileDefinitions: [
          {
            id: "181f6315-aa98-4b4d-ab1f-3c7f9df524b1",
            name: "2023-03-01T11:17:25-05:00.marc",
            status: "UPLOADED",
            jobExecutionId: job_execution_id,
            uploadDefinitionId: "d39546ed-622b-4e09-92ca-210535ff7ab4",
            createDate: "2023-02-14T13:16:19.708+00:00"
          }
        ],
        metadata: {
          createdDate: "2023-02-14T13:16:19.474+00:00",
          createdByUserId: "297649ab-3f9e-5ece-91a3-25cf700062ae",
          updatedDate: "2023-02-14T13:16:19.474+00:00",
          updatedByUserId: "297649ab-3f9e-5ece-91a3-25cf700062ae"
        }
      }
    end

    let(:process_request_body) do
      {
        uploadDefinition: upload_file_response_body,
        jobProfileInfo:
        {
          id: job_profile_id,
          name: job_profile_name,
          dataType: "MARC"
        }
      }
    end

    before do
      stub_request(:post, "#{url}/data-import/uploadDefinitions")
        .with(
          body: upload_definition_request_body.to_json,
          headers: {
            "Content-Type" => "application/json",
            "X-Okapi-Token" => "a_long_silly_token"
          }
        ).to_return(status: 200,
          body: upload_definition_response_body.to_json,
          headers: {})

      stub_request(:post, "#{url}/data-import/uploadDefinitions/d39546ed-622b-4e09-92ca-210535ff7ab4/files/181f6315-aa98-4b4d-ab1f-3c7f9df524b1")
        .with(
          body: "00098     2200037   4500245006000000\u001E0 \u001FaFolio 21: a bibliography of the Folio Society 1947-1967\u001E\u001D",
          headers: {
            "Content-Type" => "application/octet-stream",
            "X-Okapi-Token" => "a_long_silly_token"
          }
        )
        .to_return(status: 200, body: upload_file_response_body.to_json, headers: {})

      stub_request(:post, "#{url}/data-import/uploadDefinitions/d39546ed-622b-4e09-92ca-210535ff7ab4/processFiles")
        .with(
          body: process_request_body.to_json,
          headers: {
            "Content-Type" => "application/json",
            "X-Okapi-Token" => "a_long_silly_token"
          }
        )
        .to_return(status: 204, body: "", headers: {})
    end

    it "starts the import" do
      data_import.import
      expect(data_import.job_execution_id).to eq(job_execution_id)
    end
  end

  describe "#job_status" do
    before do
      data_import.instance_variable_set(:@job_execution_id, job_execution_id)

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
        expect(data_import.job_status).to eq(Failure(:pending))
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
        expect(data_import.job_status).to eq(Failure(:error))
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
        expect(data_import.job_status).to eq(Success())
      end
    end

    context "when job is not found" do
      let(:status) { 404 }
      let(:status_response_body) { "JobSummary for jobExecutionId: '#{job_execution_id}' was not found" }

      it "returns Failure(:not_found)" do
        expect(data_import.job_status).to eq(Failure(:not_found))
      end
    end
  end

  # rubocop:disable RSpec/SubjectStub
  describe "#wait" do
    context "when job is complete" do
      before do
        allow(data_import).to receive(:job_status).and_return(Failure(:not_found), Failure(:pending), Success())
      end

      it "returns Success" do
        expect(data_import.wait(wait_secs: 0.1)).to eq(Success())
        expect(data_import).to have_received(:job_status).exactly(3).times
      end
    end

    context "when job is error" do
      before do
        allow(data_import).to receive(:job_status).and_return(Failure(:pending), Failure(:pending), Failure(:error))
      end

      it "returns Failure(:error)" do
        expect(data_import.wait(wait_secs: 0.1)).to eq(Failure(:error))
        expect(data_import).to have_received(:job_status).exactly(3).times
      end
    end

    context "when too many 404s" do
      before do
        allow(data_import).to receive(:job_status).and_return(Failure(:not_found))
      end

      it "raises ResourceNotFound" do
        expect { data_import.wait(wait_secs: 0.1) }.to raise_error(FolioClient::ResourceNotFound)
        expect(data_import).to have_received(:job_status).exactly(4).times
      end
    end

    context "when timeout" do
      before do
        allow(data_import).to receive(:job_status).and_return(Failure(:pending))
      end

      it "returns Failure(:timeout)" do
        expect(data_import.wait(wait_secs: 0.5, timeout_secs: 0.25)).to eq(Failure(:timeout))
      end
    end
  end
  # rubocop:enable RSpec/SubjectStub
end
