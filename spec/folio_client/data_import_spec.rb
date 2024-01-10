# frozen_string_literal: true

RSpec.describe FolioClient::DataImport do
  let(:client) { FolioClient.instance }
  let(:data_import) { described_class.new }
  let(:args) { { url: url, login_params: login_params, okapi_headers: okapi_headers } }
  let(:url) { 'https://folio.example.org' }
  let(:login_params) { { username: 'username', password: 'password' } }
  let(:okapi_headers) { { some_bogus_headers: 'here' } }
  let(:token) { 'a_long_silly_token' }
  let(:search_instance_response) do
    { 'totalRecords' => 1,
      'instances' => [
        { 'id' => 'some_long_uuid_that_is_long',
          'title' => 'Training videos',
          'contributors' => [{ 'name' => 'Person' }],
          'isBoundWith' => false,
          'holdings' => [] }
      ] }
  end

  before do
    FolioClient.configure(**args)

    # the client is initialized with a fake token (see comment in FolioClient.configure for why).  this
    # simulates the initial obtainment of a valid token after FolioClient makes the very first post-initialization request.
    stub_request(:get, "#{url}/search/instances?query=hrid==in808")
      .to_return({ status: 401 }, { status: 200, body: search_instance_response.to_json })
    stub_request(:post, "#{url}/authn/login")
      .to_return(status: 200, body: "{\"okapiToken\" : \"#{token}\"}")

    client.fetch_external_id(hrid: 'in808')

    allow(DateTime).to receive(:now).and_return(DateTime.parse('2023-03-01T11:17:25-05:00'))
  end

  describe '#import' do
    let(:marc_file_name) { '2023-03-01T11:17:25-05:00.marc' }
    let(:records) do
      [
        MARC::Record.new.tap do |record|
          record << MARC::DataField.new('245', '0', ' ',
                                        ['a', 'Folio 21: a bibliography of the Folio Society 1947-1967'])
        end
      ]
    end
    let(:job_profile_id) { 'ae0a94d0' }
    let(:job_profile_name) { 'ETDs' }
    let(:job_execution_id) { '4ba4f4ab' }
    let(:upload_definition_request_body) do
      {
        fileDefinitions:
        [
          { name: marc_file_name }
        ]
      }
    end
    let(:upload_definition_response_body) do
      {
        id: 'd39546ed-622b-4e09-92ca-210535ff7ab4',
        metaJobExecutionId: '4ba4f4ab-d3fd-45b1-b73f-f3f0bcff17fe',
        status: 'NEW',
        createDate: '2023-02-14T13:16:19.708+00:00',
        fileDefinitions: [
          {
            id: '181f6315-aa98-4b4d-ab1f-3c7f9df524b1',
            name: marc_file_name,
            status: 'NEW',
            jobExecutionId: job_execution_id,
            uploadDefinitionId: 'd39546ed-622b-4e09-92ca-210535ff7ab4',
            createDate: '2023-02-14T13:16:19.708+00:00'
          }
        ],
        metadata: {
          createdDate: '2023-02-14T13:16:19.474+00:00',
          createdByUserId: '297649ab-3f9e-5ece-91a3-25cf700062ae',
          updatedDate: '2023-02-14T13:16:19.474+00:00',
          updatedByUserId: '297649ab-3f9e-5ece-91a3-25cf700062ae'
        }
      }
    end

    let(:upload_file_response_body) do
      {
        id: 'd39546ed-622b-4e09-92ca-210535ff7ab4',
        metaJobExecutionId: '4ba4f4ab-d3fd-45b1-b73f-f3f0bcff17fe',
        status: 'LOADED',
        createDate: '2023-02-14T13:16:19.708+00:00',
        fileDefinitions: [
          {
            id: '181f6315-aa98-4b4d-ab1f-3c7f9df524b1',
            name: marc_file_name,
            status: 'UPLOADED',
            jobExecutionId: job_execution_id,
            uploadDefinitionId: 'd39546ed-622b-4e09-92ca-210535ff7ab4',
            createDate: '2023-02-14T13:16:19.708+00:00'
          }
        ],
        metadata: {
          createdDate: '2023-02-14T13:16:19.474+00:00',
          createdByUserId: '297649ab-3f9e-5ece-91a3-25cf700062ae',
          updatedDate: '2023-02-14T13:16:19.474+00:00',
          updatedByUserId: '297649ab-3f9e-5ece-91a3-25cf700062ae'
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
          dataType: 'MARC'
        }
      }
    end

    before do
      stub_request(:post, "#{url}/data-import/uploadDefinitions")
        .with(
          body: upload_definition_request_body.to_json,
          headers: {
            'Content-Type' => 'application/json',
            'X-Okapi-Token' => 'a_long_silly_token'
          }
        ).to_return(status: 200,
                    body: upload_definition_response_body.to_json,
                    headers: {})

      stub_request(:post, "#{url}/data-import/uploadDefinitions/d39546ed-622b-4e09-92ca-210535ff7ab4/files/181f6315-aa98-4b4d-ab1f-3c7f9df524b1")
        .with(
          body: "00098     2200037   4500245006000000\u001E0 \u001FaFolio 21: a bibliography of the Folio Society 1947-1967\u001E\u001D",
          headers: {
            'Content-Type' => 'application/octet-stream',
            'X-Okapi-Token' => 'a_long_silly_token'
          }
        )
        .to_return(status: 200, body: upload_file_response_body.to_json, headers: {})

      stub_request(:post, "#{url}/data-import/uploadDefinitions/d39546ed-622b-4e09-92ca-210535ff7ab4/processFiles")
        .with(
          body: process_request_body.to_json,
          headers: {
            'Content-Type' => 'application/json',
            'X-Okapi-Token' => 'a_long_silly_token'
          }
        )
        .to_return(status: 204, body: '', headers: {})
    end

    it 'returns a JobStatus instance' do
      expect(data_import.import(records: records, job_profile_id: job_profile_id,
                                job_profile_name: job_profile_name)).to be_instance_of(FolioClient::JobStatus)
    end
  end

  describe '#job_profiles' do
    subject(:profiles) { data_import.job_profiles }

    let(:job_profiles_body) do
      <<~JOB_PROFILES_JSON
        {"jobProfiles":[{"id":"6409dcff-71fa-433a-bc6a-e70ad38a9604","name":"quickMARC - Derive a new SRS MARC Bib and Instance","description":"This job profile is used by the quickMARC Derive action to create a new SRS MARC Bib record and corresponding Inventory Instance. It cannot be edited or deleted.","dataType":"MARC","deleted":false,"userInfo":{"firstName":"System","lastName":"System","userName":"System"},"parentProfiles":[],"childProfiles":[],"hidden":false,"metadata":{"createdDate":"2021-01-14T14:00:00.000+00:00","createdByUserId":"00000000-0000-0000-0000-000000000000","updatedDate":"2021-01-14T15:00:00.462+00:00","updatedByUserId":"00000000-0000-0000-0000-000000000000"}},{"id":"6eefa4c6-bbf7-4845-ad82-de7fc5abd0e3","name":"Default - Create SRS MARC Authority","description":"Default job profile for creating MARC authority records. These records are stored in source record storage (SRS). Profile cannot be edited or deleted","dataType":"MARC","tags":{"tagList":[]},"deleted":false,"userInfo":{"firstName":"System","lastName":"System","userName":"System"},"parentProfiles":[],"childProfiles":[],"hidden":false,"metadata":{"createdDate":"2021-03-16T15:00:00.000+00:00","createdByUserId":"00000000-0000-0000-0000-000000000000","updatedDate":"2021-03-16T15:00:00.000+00:00","updatedByUserId":"00000000-0000-0000-0000-000000000000"}},{"id":"80898dee-449f-44dd-9c8e-37d5eb469b1d","name":"Default - Create Holdings and SRS MARC Holdings","description":"Default job profile for creating MARC holdings and corresponding Inventory holdings. Profile cannot be edited or deleted","dataType":"MARC","tags":{"tagList":[]},"deleted":false,"userInfo":{"firstName":"System","lastName":"System","userName":"System"},"parentProfiles":[],"childProfiles":[],"hidden":false,"metadata":{"createdDate":"2021-03-16T15:00:00.000+00:00","createdByUserId":"00000000-0000-0000-0000-000000000000","updatedDate":"2021-03-16T15:00:00.000+00:00","updatedByUserId":"00000000-0000-0000-0000-000000000000"}},{"id":"fa0262c7-5816-48d0-b9b3-7b7a862a5bc7","name":"quickMARC - Create Holdings and SRS MARC Holdings","description":"This job profile is used by the quickMARC to allow a user to create a new SRS MARC holdings record and corresponding Inventory holdings. Profile cannot be edited or deleted","dataType":"MARC","tags":{"tagList":[]},"deleted":false,"userInfo":{"firstName":"System","lastName":"System","userName":"System"},"parentProfiles":[],"childProfiles":[],"hidden":false,"metadata":{"createdDate":"2021-03-16T15:00:00.000+00:00","createdByUserId":"00000000-0000-0000-0000-000000000000","updatedDate":"2021-03-16T15:00:00.000+00:00","updatedByUserId":"00000000-0000-0000-0000-000000000000"}},{"id":"e34d7b92-9b83-11eb-a8b3-0242ac130003","name":"Default - Create instance and SRS MARC Bib","description":"This job profile creates SRS MARC Bib records and corresponding Inventory Instances using the library's default MARC-to-Instance mapping. It can be edited, duplicated, or deleted.","dataType":"MARC","deleted":false,"userInfo":{"firstName":"System","lastName":"System","userName":"System"},"parentProfiles":[],"childProfiles":[],"hidden":false,"metadata":{"createdDate":"2021-04-13T14:00:00.000+00:00","createdByUserId":"00000000-0000-0000-0000-000000000000","updatedDate":"2021-04-13T15:00:00.462+00:00","updatedByUserId":"00000000-0000-0000-0000-000000000000"}},{"id":"d0ebb7b0-2f0f-11eb-adc1-0242ac120002","name":"Inventory Single Record - Default Create Instance","description":"Triggered by an action in Inventory, this job profile imports a single record from an external system, to create an Instance and MARC record","dataType":"MARC","tags":{"tagList":[]},"deleted":false,"userInfo":{"firstName":"System","lastName":"System","userName":"System"},"parentProfiles":[],"childProfiles":[],"hidden":false,"metadata":{"createdDate":"2020-11-23T12:00:00.000+00:00","createdByUserId":"00000000-0000-0000-0000-000000000000","createdByUsername":"System","updatedDate":"2020-11-24T12:00:00.000+00:00","updatedByUserId":"00000000-0000-0000-0000-000000000000","updatedByUsername":"System"}},{"id":"91f9b8d6-d80e-4727-9783-73fb53e3c786","name":"Inventory Single Record - Default Update Instance","description":"Triggered by an action in Inventory, this job profile imports a single record from an external system, to update an existing Instance, and either create a new MARC record or update an existing MARC record","dataType":"MARC","deleted":false,"userInfo":{"firstName":"System","lastName":"System","userName":"System"},"parentProfiles":[],"childProfiles":[],"hidden":false,"metadata":{"createdDate":"2020-11-30T09:07:47.667+00:00","createdByUserId":"6a010e5b-5421-5b1c-9b52-568b37038575","updatedDate":"2020-11-30T09:09:10.382+00:00","updatedByUserId":"6a010e5b-5421-5b1c-9b52-568b37038575"}},{"id":"ae0a94d0-1f8e-4177-bcf9-c3a90e4c9429","name":"ETDs New","description":"Test for ETD new records","dataType":"MARC","deleted":false,"userInfo":{"lastName":"Superuser","userName":"libsys_admin"},"parentProfiles":[],"childProfiles":[],"hidden":false,"metadata":{"createdDate":"2023-03-23T16:16:52.604+00:00","createdByUserId":"3e2ed889-52f2-45ce-8a30-8767266f07d2","updatedDate":"2023-03-23T16:16:52.604+00:00","updatedByUserId":"3e2ed889-52f2-45ce-8a30-8767266f07d2"}},{"id":"7b590640-e924-454f-a4c4-254797c6b94a","name":"SUL load MARC","description":"","dataType":"MARC","deleted":false,"userInfo":{"lastName":"Superuser","userName":"libsys_admin"},"parentProfiles":[],"childProfiles":[],"hidden":false,"metadata":{"createdDate":"2023-03-23T16:16:56.696+00:00","createdByUserId":"3e2ed889-52f2-45ce-8a30-8767266f07d2","updatedDate":"2023-03-23T16:16:56.696+00:00","updatedByUserId":"3e2ed889-52f2-45ce-8a30-8767266f07d2"}},{"id":"2af1026b-1c90-4ebd-8b45-1a1d4b44fb27","name":"Internet","description":"","dataType":"MARC","deleted":false,"userInfo":{"lastName":"Superuser","userName":"libsys_admin"},"parentProfiles":[],"childProfiles":[],"hidden":false,"metadata":{"createdDate":"2023-03-23T16:16:57.195+00:00","createdByUserId":"3e2ed889-52f2-45ce-8a30-8767266f07d2","updatedDate":"2023-03-23T16:16:57.195+00:00","updatedByUserId":"3e2ed889-52f2-45ce-8a30-8767266f07d2"}}],"totalRecords":24}
      JOB_PROFILES_JSON
    end

    before do
      stub_request(:get, "#{url}/data-import-profiles/jobProfiles")
        .with(
          headers: {
            'Content-Type' => 'application/json',
            'X-Okapi-Token' => 'a_long_silly_token'
          }
        )
        .to_return(status: 200, body: job_profiles_body, headers: {})
    end

    it 'returns the expected number of profiles' do
      expect(profiles.count).to eq(10)
    end

    it 'returns the expected fields for profiles' do
      expect(profiles).to all(have_keys('id', 'name', 'description', 'dataType'))
    end

    # NOTE: not checking all values; just using dataType as a sample
    it 'returns the expected values for profiles' do
      expect(profiles.map { |profile| profile['dataType'] }).to all(eq('MARC'))
    end
  end
end
