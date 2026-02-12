# frozen_string_literal: true

require 'marc'

RSpec.describe FolioClient do
  subject(:client) do
    described_class.configure(**args)
  end

  let(:args) { { url: url, login_params: login_params, okapi_headers: okapi_headers } }
  let(:url) { 'https://folio.example.org' }
  let(:login_params) { { username: 'username', password: 'password' } }
  let(:okapi_headers) { { some_bogus_headers: 'here' } }
  let(:cookie_headers) do
    { 'Set-Cookie': "folioAccessToken=#{token}; Expires=Fri, 22 Sep 2050 14:30:10 GMT; Path=/; Secure; HTTPOnly; SameSite=None" }
  end
  let(:token) { 'a_folio_access_token' }
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
    # the client is initialized with a fake token (see comment in FolioClient.configure for why).  this
    # simulates the initial obtainment of a valid token after FolioClient makes the very first post-initialization request.
    stub_request(:get, "#{url}/search/instances?query=hrid==in808")
      .to_return({ status: 401 }, { status: 200, body: search_instance_response.to_json })
    stub_request(:post, "#{url}/authn/login-with-expiry")
      .to_return(status: 200, headers: cookie_headers)
    client.fetch_external_id(hrid: 'in808')
  end

  it 'has a version number' do
    expect(FolioClient::VERSION).not_to be_nil
  end

  it 'has singleton behavior' do
    expect(described_class.instance).to be_a(described_class)
  end

  describe '.configure' do
    it 'stores passed in values in the config' do
      expect(client.config.login_params).to eq(login_params)
      expect(client.config.url).to eq(url)
      expect(client.config.okapi_headers).to eq(okapi_headers)
    end

    it 'gets the default timeout value' do
      expect(client.config.timeout).to eq(120)
    end

    it 'stores the fetched token in the config' do
      expect(client.config.token).to eq(token)
    end

    it 'returns the singleton class' do
      expect(client).to be described_class
    end
  end

  describe '#force_token_refresh!' do
    let(:refreshed_token) { 'another dummy token value' }
    let(:refreshed_cookie_headers) do
      { 'Set-Cookie': "folioAccessToken=#{refreshed_token}; Expires=Fri, 22 Sep 2050 14:30:10 GMT; Path=/; Secure; HTTPOnly; SameSite=None" }
    end

    before do
      stub_request(:post, "#{url}/authn/login-with-expiry")
        .to_return(status: 200, headers: refreshed_cookie_headers)
    end

    it 'forces a token refresh' do
      expect { client.force_token_refresh! }
        .to change(client.config, :token)
        .from(token)
        .to(refreshed_token)
    end
  end

  describe '#get' do
    let(:path) { 'some_path' }
    let(:response) { { some: 'response' }.to_json }

    before do
      stub_request(:get, "#{url}/#{path}?id=5")
        .to_return(status: 200, body: response.to_json)
    end

    it 'calls the API with a get' do
      expect(client.get(path, { id: 5 })).to eq(response)
    end
  end

  describe '#post' do
    let(:path) { 'some_path' }
    let(:response) { { some: 'response' }.to_json }

    context 'with a JSON body' do
      before do
        stub_request(:post, "#{url}/#{path}")
          .with(
            body: '{"id":5}',
            headers: {
              'Accept' => 'application/json, text/plain',
              'Content-Type' => 'application/json',
              'Some-Bogus-Headers' => 'here',
              'X-Okapi-Token' => 'a_folio_access_token'
            }
          )
          .to_return(status: 200, body: response.to_json, headers: {})
      end

      it 'calls the API with a post' do
        expect(client.post(path, { id: 5 })).to eq(response)
      end
    end

    context 'with no body' do
      before do
        stub_request(:post, "#{url}/#{path}")
          .with(
            body: '',
            headers: {
              'Accept' => 'application/json, text/plain',
              'Some-Bogus-Headers' => 'here',
              'X-Okapi-Token' => 'a_folio_access_token'
            }
          )
          .to_return(status: 200, body: response.to_json, headers: {})
      end

      it 'calls the API with a post' do
        expect(client.post(path)).to eq(response)
      end
    end

    context 'with non-JSON body' do
      before do
        stub_request(:post, "#{url}/#{path}")
          .with(
            body: 'foobar',
            headers: {
              'Accept' => 'application/json, text/plain',
              'Content-Type' => 'text/plain',
              'Some-Bogus-Headers' => 'here',
              'X-Okapi-Token' => 'a_folio_access_token'
            }
          )
          .to_return(status: 200, body: response.to_json, headers: {})
      end

      it 'calls the API with a post' do
        expect(client.post(path, 'foobar', content_type: 'text/plain')).to eq(response)
      end
    end
  end

  describe '#put' do
    let(:path) { 'some_path' }
    let(:response) { { some: 'response' }.to_json }

    context 'with a JSON body' do
      before do
        stub_request(:put, "#{url}/#{path}")
          .with(
            body: '{"id":5}',
            headers: {
              'Accept' => 'application/json, text/plain',
              'Content-Type' => 'application/json',
              'Some-Bogus-Headers' => 'here',
              'X-Okapi-Token' => 'a_folio_access_token'
            }
          )
          .to_return(status: 200, body: response.to_json, headers: {})
      end

      it 'calls the API with a put' do
        expect(client.put(path, { id: 5 })).to eq(response)
      end
    end

    context 'with no body' do
      before do
        stub_request(:put, "#{url}/#{path}")
          .with(
            body: '',
            headers: {
              'Accept' => 'application/json, text/plain',
              'Some-Bogus-Headers' => 'here',
              'X-Okapi-Token' => 'a_folio_access_token'
            }
          )
          .to_return(status: 200, body: response.to_json, headers: {})
      end

      it 'calls the API with a put' do
        expect(client.put(path)).to eq(response)
      end
    end

    context 'with non-JSON body' do
      before do
        stub_request(:put, "#{url}/#{path}")
          .with(
            body: 'foobar',
            headers: {
              'Accept' => 'application/json, text/plain',
              'Content-Type' => 'text/plain',
              'Some-Bogus-Headers' => 'here',
              'X-Okapi-Token' => 'a_folio_access_token'
            }
          )
          .to_return(status: 200, body: response.to_json, headers: {})
      end

      it 'calls the API with a put' do
        expect(client.put(path, 'foobar', content_type: 'text/plain')).to eq(response)
      end
    end
  end

  describe '.fetch_hrid' do
    let(:barcode) { '123456' }

    before do
      allow(described_class.instance).to receive(:fetch_hrid).with(barcode: barcode)
    end

    it 'invokes instance#fetch_hrid' do
      client.fetch_hrid(barcode: barcode)
      expect(client.instance).to have_received(:fetch_hrid).with(barcode: barcode)
    end
  end

  describe '#fetch_hrid' do
    let(:barcode) { '123456' }
    let(:inventory) { instance_double(described_class::Inventory) }

    before do
      allow(described_class::Inventory).to receive(:new).and_return(inventory)
      allow(inventory).to receive(:fetch_hrid)
    end

    it 'invokes Inventory#fetch_hrid' do
      client.fetch_hrid(barcode: barcode)
      expect(inventory).to have_received(:fetch_hrid).once
    end
  end

  describe '.fetch_external_id' do
    let(:hrid) { 'in00000000067' }
    let(:external_id) { '5108040a-65bc-40ed-bd50-265958301ce4' }

    before do
      allow(described_class.instance).to receive(:fetch_external_id).with(hrid: hrid).and_return(external_id)
    end

    it 'invokes instance#fetch_external_id and passes along the return value' do
      expect(client.fetch_external_id(hrid: hrid)).to eq external_id
      expect(client.instance).to have_received(:fetch_external_id).with(hrid: hrid)
    end
  end

  describe '#fetch_external_id' do
    let(:hrid) { 'in00000000067' }
    let(:inventory) { instance_double(described_class::Inventory) }
    let(:external_id) { '5108040a-65bc-40ed-bd50-265958301ce4' }

    before do
      allow(described_class::Inventory).to receive(:new).and_return(inventory)
      allow(inventory).to receive(:fetch_external_id).with(hrid: hrid).and_return(external_id)
    end

    it 'invokes Inventory#fetch_external_id and passes along the return value' do
      expect(client.fetch_external_id(hrid: hrid)).to eq external_id
      expect(inventory).to have_received(:fetch_external_id).once
    end
  end

  describe '.fetch_instance_info' do
    let(:external_id) { '5108040a-65bc-40ed-bd50-265958301ce4' }
    let(:instance_info) do
      { 'id' => external_id, 'version' => 2, 'hrid' => 'in00000000010' }
    end

    before do
      allow(described_class.instance).to receive(:fetch_instance_info).with(external_id: external_id).and_return(instance_info)
    end

    it 'invokes instance#fetch_instance_info and passes along the return value' do
      expect(client.fetch_instance_info(external_id: external_id)).to eq instance_info
      expect(client.instance).to have_received(:fetch_instance_info).with(external_id: external_id)
    end
  end

  describe '#fetch_instance_info' do
    let(:external_id) { '5108040a-65bc-40ed-bd50-265958301ce4' }
    let(:inventory) { instance_double(described_class::Inventory) }
    let(:instance_info) do
      { 'id' => external_id, 'version' => 2, 'hrid' => 'in00000000010' }
    end

    before do
      allow(described_class::Inventory).to receive(:new).and_return(inventory)
      allow(inventory).to receive(:fetch_instance_info).with(external_id: external_id).and_return(instance_info)
    end

    it 'invokes Inventory#fetch_instance_info and passes along the return value' do
      expect(client.fetch_instance_info(external_id: external_id)).to eq instance_info
      expect(inventory).to have_received(:fetch_instance_info).once
    end
  end

  describe '.fetch_marc_hash' do
    let(:instance_hrid) { 'a12854819' }

    before do
      allow(described_class.instance).to receive(:fetch_marc_hash).with(instance_hrid: instance_hrid)
    end

    it 'invokes instance#fetch_marc_hash' do
      client.fetch_marc_hash(instance_hrid: instance_hrid)
      expect(client.instance).to have_received(:fetch_marc_hash).with(instance_hrid: instance_hrid)
    end
  end

  describe '#fetch_marc_hash' do
    let(:instance_hrid) { '123456' }
    let(:source_storage) { instance_double(described_class::SourceStorage) }

    before do
      allow(described_class::SourceStorage).to receive(:new).and_return(source_storage)
      allow(source_storage).to receive(:fetch_marc_hash)
    end

    it 'invokes SourceStorage#fetch_marc_hash' do
      client.fetch_marc_hash(instance_hrid: instance_hrid)
      expect(source_storage).to have_received(:fetch_marc_hash).once
    end
  end

  describe '.fetch_marc_xml' do
    let(:instance_hrid) { 'a12854819' }

    before do
      allow(described_class.instance).to receive(:fetch_marc_xml).with(instance_hrid: instance_hrid)
    end

    it 'invokes instance#fetch_marc_xml' do
      client.fetch_marc_xml(instance_hrid: instance_hrid)
      expect(client.instance).to have_received(:fetch_marc_xml).with(instance_hrid: instance_hrid)
    end
  end

  describe '#fetch_marc_xml' do
    let(:instance_hrid) { '123456' }
    let(:source_storage) { instance_double(described_class::SourceStorage) }

    before do
      allow(described_class::SourceStorage).to receive(:new).and_return(source_storage)
      allow(source_storage).to receive(:fetch_marc_xml)
    end

    it 'invokes SourceStorage#fetch_marc_xml' do
      client.fetch_marc_xml(instance_hrid: instance_hrid)
      expect(source_storage).to have_received(:fetch_marc_xml).once
    end
  end

  describe '.fetch_location' do
    let(:location_id) { 'd9cd0bed-1b49-4b5e-a7bd-064b8d177231' }
    let(:location_response) do
      {
        'id' => 'd9cd0bed-1b49-4b5e-a7bd-064b8d177231',
        'name' => 'Miller General Stacks',
        'code' => 'UA/CB/LC/GS',
        'isActive' => true,
        'description' => 'The very general stacks of Miller',
        'discoveryDisplayName' => 'Miller General',
        'institutionId' => '4b2a3d97-01c3-4ef3-98a5-ae4e853429b4',
        'campusId' => 'b595d838-b1d5-409e-86ac-af3b41bde0be',
        'libraryId' => 'e2889f93-92f2-4937-b944-5452a575367e',
        'details' => {
          'a' => 'b',
          'foo' => 'bar'
        },
        'primaryServicePoint' => '79faacf1-4ba4-42c7-8b2a-566b259e4641',
        'servicePointIds' => [
          '79faacf1-4ba4-42c7-8b2a-566b259e4641'
        ]
      }
    end

    before do
      allow(described_class.instance).to receive(:fetch_location).with(location_id:).and_return(location_response)
    end

    it 'invokes instance#fetch_location and passes along the return value' do
      expect(client.fetch_location(location_id:)).to eq location_response
      expect(client.instance).to have_received(:fetch_location).with(location_id:)
    end
  end

  describe '#fetch_location' do
    let(:location_id) { 'd9cd0bed-1b49-4b5e-a7bd-064b8d177231' }
    let(:location_response) do
      {
        'id' => 'd9cd0bed-1b49-4b5e-a7bd-064b8d177231',
        'name' => 'Miller General Stacks',
        'code' => 'UA/CB/LC/GS',
        'isActive' => true,
        'description' => 'The very general stacks of Miller',
        'discoveryDisplayName' => 'Miller General',
        'institutionId' => '4b2a3d97-01c3-4ef3-98a5-ae4e853429b4',
        'campusId' => 'b595d838-b1d5-409e-86ac-af3b41bde0be',
        'libraryId' => 'e2889f93-92f2-4937-b944-5452a575367e',
        'details' => {
          'a' => 'b',
          'foo' => 'bar'
        },
        'primaryServicePoint' => '79faacf1-4ba4-42c7-8b2a-566b259e4641',
        'servicePointIds' => [
          '79faacf1-4ba4-42c7-8b2a-566b259e4641'
        ]
      }
    end

    before do
      stub_request(:get, "#{url}/locations/#{location_id}")
        .to_return(status: 200, body: location_response.to_json)
    end

    it 'fetches location data including campusId' do
      result = client.fetch_location(location_id: location_id)
      expect(result).to eq(location_response)
      expect(result['campusId']).to eq('b595d838-b1d5-409e-86ac-af3b41bde0be')
    end
  end

  describe '#fetch_holdings' do
    let(:hrid) { 'in00000000067' }
    let(:holdings_array) do
      [
        {
          'id' => '7f89e96c-478c-4ca2-bb85-0a1c5b0c6f3e',
          'instanceId' => '5108040a-65bc-40ed-bd50-265958301ce4',
          'permanentLocationId' => 'd9cd0bed-1b49-4b5e-a7bd-064b8d177231',
          'discoverySuppress' => false,
          'hrid' => 'ho00000000010',
          'holdingsTypeId' => '03c9c400-b9e3-4a07-ac0e-05ab470233ed',
          'callNumber' => 'ABC 123'
        },
        {
          'id' => '8a89e96c-478c-4ca2-bb85-0a1c5b0c6f3f',
          'instanceId' => '5108040a-65bc-40ed-bd50-265958301ce4',
          'permanentLocationId' => 'b595d838-b1d5-409e-86ac-af3b41bde0be',
          'discoverySuppress' => true,
          'hrid' => 'ho00000000011',
          'holdingsTypeId' => '03c9c400-b9e3-4a07-ac0e-05ab470233ed',
          'callNumber' => 'DEF 456'
        }
      ]
    end
    let(:search_instance_response) do
      {
        'totalRecords' => 1,
        'instances' => [
          {
            'id' => '5108040a-65bc-40ed-bd50-265958301ce4',
            'title' => 'TOPICS IN CONVEX OPTIMIZATION FOR MACHINE LEARNING',
            'holdings' => holdings_array
          }
        ]
      }
    end

    before do
      stub_request(:get, "#{url}/search/instances?expandAll=true&query=hrid==#{hrid}")
        .to_return(status: 200, body: search_instance_response.to_json)
    end

    it 'returns the holdings array for the instance' do
      result = client.fetch_holdings(hrid: hrid)
      expect(result).to eq(holdings_array)
      expect(result.length).to eq(2)
    end
  end

  describe '.data_import' do
    let(:job_profile_id) { '4ba4f4ab' }
    let(:job_profile_name) { 'ETDs' }
    let(:records) { [instance_double(MARC::Record)] }

    before do
      allow(described_class.instance).to receive(:data_import)
        .with(job_profile_id: job_profile_id, job_profile_name: job_profile_name, records: records)
    end

    it 'invokes instance#data_import' do
      client.data_import(job_profile_id: job_profile_id, job_profile_name: job_profile_name, records: records)
      expect(client.instance).to have_received(:data_import)
        .with(job_profile_id: job_profile_id, job_profile_name: job_profile_name, records: records)
    end
  end

  describe '#data_import' do
    let(:job_profile_id) { '4ba4f4ab' }
    let(:job_profile_name) { 'ETDs' }
    let(:records) { [instance_double(MARC::Record)] }
    let(:importer) { instance_double(described_class::DataImport) }

    before do
      allow(described_class::DataImport).to receive(:new).and_return(importer)
      allow(importer).to receive(:import)
    end

    it 'invokes DataImport#import' do
      client.data_import(job_profile_id: job_profile_id, job_profile_name: job_profile_name, records: records)
      expect(importer).to have_received(:import).once
    end
  end

  describe '.job_profiles' do
    before do
      allow(described_class.instance).to receive(:job_profiles)
    end

    it 'invokes instance#job_profiles' do
      client.job_profiles
      expect(client.instance).to have_received(:job_profiles)
    end
  end

  describe '#job_profiles' do
    let(:importer) { instance_double(described_class::DataImport) }

    before do
      allow(described_class::DataImport).to receive(:new).and_return(importer)
      allow(importer).to receive(:job_profiles)
    end

    it 'invokes DataImport#job_profiles' do
      client.job_profiles
      expect(importer).to have_received(:job_profiles).once
    end
  end

  describe '.has_instance_status?' do
    let(:hrid) { 'a12854819' }
    let(:status_id) { '1a2b3c4d-1234' }

    before do
      allow(described_class.instance).to receive(:has_instance_status?).with(hrid: hrid, status_id: status_id)
    end

    it 'invokes instance#has_instance_status?' do
      client.has_instance_status?(hrid: hrid, status_id: status_id)
      expect(client.instance).to have_received(:has_instance_status?).with(hrid: hrid, status_id: status_id)
    end
  end

  describe '#has_instance_status?' do
    let(:hrid) { 'a12854819' }
    let(:status_id) { '1a2b3c4d-1234' }
    let(:inventory) { instance_double(described_class::Inventory) }

    before do
      allow(described_class::Inventory).to receive(:new).and_return(inventory)
      allow(inventory).to receive(:has_instance_status?)
    end

    it 'invokes Inventory#has_instance_status?' do
      client.has_instance_status?(hrid: hrid, status_id: status_id)
      expect(inventory).to have_received(:has_instance_status?).once
    end
  end

  describe '.organizations' do
    before do
      allow(described_class.instance).to receive(:organizations)
    end

    it 'invokes instance#organizations' do
      client.organizations
      expect(client.instance).to have_received(:organizations)
    end
  end

  describe '#organizations' do
    let(:organizations) { instance_double(described_class::Organizations) }

    before do
      allow(described_class::Organizations).to receive(:new).and_return(organizations)
      allow(organizations).to receive(:fetch_list)
    end

    it 'invokes Organizations#fetch_list' do
      client.organizations
      expect(organizations).to have_received(:fetch_list).once
    end
  end

  describe '.organization_interfaces' do
    before do
      allow(described_class.instance).to receive(:organization_interfaces).with(query: 'something')
    end

    it 'invokes instance#organization_interfaces' do
      client.organization_interfaces(query: 'something')
      expect(client.instance).to have_received(:organization_interfaces).with(query: 'something')
    end
  end

  describe '#organization_interfaces' do
    let(:organizations) { instance_double(described_class::Organizations) }

    before do
      allow(described_class::Organizations).to receive(:new).and_return(organizations)
      allow(organizations).to receive(:fetch_interface_list).with(query: 'something')
    end

    it 'invokes Organizations#fetch_interface_list' do
      client.organization_interfaces(query: 'something')
      expect(organizations).to have_received(:fetch_interface_list).with(query: 'something').once
    end
  end

  describe '.interface_details' do
    before do
      allow(described_class.instance).to receive(:interface_details).with(id: 'something')
    end

    it 'invokes instance#interface_details' do
      client.interface_details(id: 'something')
      expect(client.instance).to have_received(:interface_details).with(id: 'something')
    end
  end

  describe '#interface_details' do
    let(:organizations) { instance_double(described_class::Organizations) }

    before do
      allow(described_class::Organizations).to receive(:new).and_return(organizations)
      allow(organizations).to receive(:fetch_interface_details).with(id: 'something')
    end

    it 'invokes Organizations#fetch_interface_details' do
      client.interface_details(id: 'something')
      expect(organizations).to have_received(:fetch_interface_details).with(id: 'something').once
    end
  end

  describe '.users' do
    before do
      allow(described_class.instance).to receive(:users)
    end

    it 'invokes instance#users' do
      client.users
      expect(client.instance).to have_received(:users)
    end
  end

  describe '#users' do
    let(:users) { instance_double(described_class::Users) }

    before do
      allow(described_class::Users).to receive(:new).and_return(users)
      allow(users).to receive(:fetch_list)
    end

    it 'invokes Users#fetch_list' do
      client.users
      expect(users).to have_received(:fetch_list).once
    end
  end

  describe '.user_details' do
    before do
      allow(described_class.instance).to receive(:user_details).with(id: 'something')
    end

    it 'invokes instance#user_details' do
      client.user_details(id: 'something')
      expect(client.instance).to have_received(:user_details).with(id: 'something')
    end
  end

  describe '#user_details' do
    let(:users) { instance_double(described_class::Users) }

    before do
      allow(described_class::Users).to receive(:new).and_return(users)
      allow(users).to receive(:fetch_user_details).with(id: 'something')
    end

    it 'invokes Users#fetch_user_details' do
      client.user_details(id: 'something')
      expect(users).to have_received(:fetch_user_details).with(id: 'something').once
    end
  end

  # Tests that we request a new token and then retry the same HTTP call, if the HTTP call
  # returns an unauthorized error
  context 'when token is expired' do
    let(:inventory) { instance_double(FolioClient::Inventory, fetch_hrid: nil) }
    let(:hrid) { 'in56789' }
    let(:expired_token) { token }
    let(:new_token) { 'new_token' }
    let(:refreshed_cookie_headers) do
      { 'Set-Cookie': "folioAccessToken=#{new_token}; Expires=Fri, 22 Sep 2050 14:30:10 GMT; Path=/; Secure; HTTPOnly; SameSite=None" }
    end
    let(:barcode) { '123456' }
    let(:instance_uuid) { 'd71e654b-ca5e-44c0-9621-ae86ffd528d3' }
    let(:inventory_instance_response) do
      { 'id' => instance_uuid,
        '_version' => '1',
        'hrid' => hrid,
        'source' => 'FOLIO',
        'title' => 'Training videos',
        'isBoundWith' => false,
        'contributors' => [],
        'publication' => [],
        'electronicAccess' => [],
        'instanceTypeId' => '225faa14-f9bf-4ecd-990d-69433c912434',
        'statusId' => '2a340d34-6b70-443a-bb1b-1b8d1c65d862',
        'statusUpdatedDate' => '2023-02-10T21:19:22.285+0000',
        'metadata' => {},
        'succeedingTitles' => [] }
    end
    let(:search_instance_response) do
      { 'totalRecords' => 1,
        'instances' => [
          { 'id' => instance_uuid,
            'title' => 'Training videos',
            'contributors' => [{ 'name' => 'Person' }],
            'isBoundWith' => false,
            'holdings' => [] }
        ] }
    end

    before do
      stub_request(:post, "#{url}/authn/login-with-expiry")
        .to_return(
          { status: 200, headers: refreshed_cookie_headers }
        )
      stub_request(:get, "#{url}/search/instances?query=items.barcode==#{barcode}")
        .with(headers: { 'x-okapi-token': expired_token })
        .to_return(
          { status: 401, body: 'invalid authN token' }
        )
      stub_request(:get, "#{url}/search/instances?query=items.barcode==#{barcode}")
        .with(headers: { 'x-okapi-token': new_token })
        .to_return(
          { status: 200, body: search_instance_response.to_json }
        )
      stub_request(:get, "#{url}/inventory/instances/#{instance_uuid}")
        .with(headers: { 'x-okapi-token': new_token })
        .to_return(status: 200, body: inventory_instance_response.to_json)
    end

    it 'fetches new token and retries' do
      expect { client.fetch_hrid(barcode: barcode) }
        .to change(client.config, :token)
        .from(expired_token)
        .to(new_token)
    end
  end

  describe '.edit_marc_json' do
    let(:hrid) { 'in00000000067' }
    let(:mock_marc_json) do
      { '001' => 'foo', '856' => 'bar', '245' => 'baz' }
    end

    before do
      allow(described_class.instance).to receive(:edit_marc_json).and_yield(mock_marc_json)
    end

    it "invokes instance#edit_marc_json on the caller's block" do
      block_ran = false
      client.edit_marc_json(hrid: hrid) do |marc_json|
        expect(marc_json).to be mock_marc_json
        block_ran = true
      end
      expect(block_ran).to be true
      expect(client.instance).to have_received(:edit_marc_json).with(hrid: hrid)
    end
  end

  describe '#edit_marc_json' do
    let(:hrid) { 'in00000000067' }
    let(:records_editor) { instance_double(described_class::RecordsEditor) }
    let(:mock_marc_json) do
      { '001' => 'foo', '856' => 'bar', '245' => 'baz' }
    end

    before do
      allow(described_class::RecordsEditor).to receive(:new).and_return(records_editor)
      allow(records_editor).to receive(:edit_marc_json).and_yield(mock_marc_json)
    end

    it "invokes RecordsEditor#edit_marc_json on the caller's block" do
      block_ran = false
      client.edit_marc_json(hrid: hrid) do |marc_json|
        expect(marc_json).to be mock_marc_json
        block_ran = true
      end
      expect(block_ran).to be true
      expect(records_editor).to have_received(:edit_marc_json).with(hrid: hrid)
    end
  end
end
