# frozen_string_literal: true

RSpec.describe FolioClient::DataImport do
  let(:data_import) { described_class.new(client, marc: marc, job_profile_id: job_profile_id, job_profile_name: job_profile_name) }
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

    it "returns a JobStatus instance" do
      expect(data_import.import).to be_instance_of(FolioClient::JobStatus)
    end
  end
end
