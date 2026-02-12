# frozen_string_literal: true

RSpec.describe FolioClient::Inventory do
  subject(:inventory) { described_class.new }

  let(:args) { { url: url, login_params: login_params, okapi_headers: okapi_headers } }
  let(:url) { 'https://folio.example.org' }
  let(:login_params) { { username: 'username', password: 'password' } }
  let(:okapi_headers) { { some_bogus_headers: 'here' } }
  let(:token) { 'a_long_silly_token' }
  let(:cookie_headers) do
    { 'Set-Cookie': "folioAccessToken=#{token}; Expires=Fri, 22 Sep 2050 14:30:10 GMT; Path=/; Secure; HTTPOnly; SameSite=None" }
  end
  let(:client) { FolioClient.instance }
  let(:barcode) { '123456' }
  let(:instance_uuid) { 'some_long_uuid_that_is_long' }
  let(:hrid) { 'a12854819' }

  before do
    FolioClient.configure(**args)

    stub_request(:post, "#{url}/authn/login-with-expiry")
      .to_return(status: 200, headers: cookie_headers)
  end

  context 'when looking up a barcode' do
    before do
      stub_request(:get, "#{url}/search/instances?query=items.barcode==#{barcode}")
        .to_return(status: 200, body: search_instance_response.to_json)
      stub_request(:get, "#{url}/inventory/instances/#{instance_uuid}")
        .to_return(status: 200, body: inventory_instance_response.to_json)
    end

    context 'when barcode is found and search for instance_uuid returns a result' do
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
      let(:inventory_instance_response) do
        { 'id' => 'd71e654b-ca5e-44c0-9621-ae86ffd528d3',
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

      it 'returns the instance hrid' do
        expect(inventory.fetch_hrid(barcode: barcode)).to eq(hrid)
      end
    end

    context 'when barcode is not found' do
      let(:search_instance_response) do
        { 'totalRecords' => 0,
          'instances' => [] }
      end
      let(:inventory_instance_response) { nil }

      it 'returns nil' do
        expect(inventory.fetch_hrid(barcode: barcode)).to be_nil
      end
    end

    context 'when barcode is found but search for instance_uuid returns no results' do
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
      let(:inventory_instance_response) { {} }

      it 'returns nil' do
        expect(inventory.fetch_hrid(barcode: barcode)).to be_nil
      end
    end
  end

  context 'when checking whether an item is cataloged' do
    let(:status_id) { '1a2b3c4d-1234' }

    before do
      stub_request(:get, "#{url}/inventory/instances?query=hrid==#{hrid}")
        .to_return(status: 200, body: inventory_instance_response.to_json)
    end

    context 'when instance has cataloged status' do
      let(:inventory_instance_response) do
        { 'instances' => [
            { 'id' => 'd71e654b-ca5e-44c0-9621-ae86ffd528d3',
              '_version' => '1',
              'hrid' => hrid,
              'source' => 'FOLIO',
              'title' => 'Training videos',
              'isBoundWith' => false,
              'contributors' => [],
              'publication' => [],
              'electronicAccess' => [],
              'instanceTypeId' => '225faa14-f9bf-4ecd-990d-69433c912434',
              'statusId' => status_id,
              'statusUpdatedDate' => '2023-02-10T21:19:22.285+0000',
              'metadata' => {},
              'succeedingTitles' => [] }
          ],
          'totalRecords' => 1 }
      end

      it 'returns true' do
        expect(inventory.has_instance_status?(hrid: hrid, status_id: status_id)).to be true
      end
    end

    context 'when instance has a different status' do
      let(:inventory_instance_response) do
        { 'instances' => [
            { 'id' => 'd71e654b-ca5e-44c0-9621-ae86ffd528d3',
              '_version' => '1',
              'hrid' => hrid,
              'source' => 'FOLIO',
              'title' => 'Training videos',
              'isBoundWith' => false,
              'contributors' => [],
              'publication' => [],
              'electronicAccess' => [],
              'instanceTypeId' => '225faa14-f9bf-4ecd-990d-69433c912434',
              'statusId' => '2b3c4d5e-0987',
              'statusUpdatedDate' => '2023-02-10T21:19:22.285+0000',
              'metadata' => {},
              'succeedingTitles' => [] }
          ],
          'totalRecords' => 1 }
      end

      it 'returns false' do
        expect(inventory.has_instance_status?(hrid: hrid, status_id: status_id)).to be false
      end
    end

    context 'when instance has no status' do
      let(:inventory_instance_response) do
        { 'instances' => [
            { 'id' => 'd71e654b-ca5e-44c0-9621-ae86ffd528d3',
              '_version' => '1',
              'hrid' => hrid,
              'source' => 'FOLIO',
              'title' => 'Training videos',
              'isBoundWith' => false,
              'contributors' => [],
              'publication' => [],
              'electronicAccess' => [],
              'instanceTypeId' => '225faa14-f9bf-4ecd-990d-69433c912434',
              'metadata' => {},
              'succeedingTitles' => [] }
          ],
          'totalRecords' => 1 }
      end

      it 'returns false' do
        expect(inventory.has_instance_status?(hrid: hrid, status_id: status_id)).to be false
      end
    end

    context 'when no matching instance found' do
      let(:inventory_instance_response) do
        { 'totalRecords' => 0,
          'instances' => [] }
      end

      it 'raises an error' do
        expect do
          inventory.has_instance_status?(hrid: hrid,
                                         status_id: status_id)
        end.to raise_error(FolioClient::ResourceNotFound, "No matching instance found for #{hrid}")
      end
    end
  end

  describe '#fetch_external_id' do
    let(:hrid) { 'in00000000067' }
    let(:external_id) { '5108040a-65bc-40ed-bd50-265958301ce4' }
    let(:search_instance_response) do
      { 'totalRecords' => 1,
        'instances' =>
        [{ 'id' => external_id,
           'title' => 'TOPICS IN CONVEX OPTIMIZATION FOR MACHINE LEARNING / Youngsuk Park.',
           'contributors' => [{ 'name' => 'Park, Youngsuk,',
                                'contributorNameTypeId' => '2b94c631-fca9-4892-a730-03ee529ffe2a', 'primary' => true }],
           'publication' => [{ 'publisher' => '[Stanford University]', 'dateOfPublication' => '2020' },
                             { 'dateOfPublication' => '©2020' }],
           'discoverySuppress' => false,
           'isBoundWith' => false,
           'electronicAccess' => [],
           'notes' => [],
           'items' => [],
           'holdings' => [] }] }
    end

    before do
      stub_request(:get, "#{url}/search/instances?query=hrid==#{hrid}")
        .to_return(status: 200, body: search_instance_response.to_json)
    end

    it 'returns the external_id for the HRID when there is one result found' do
      expect(inventory.fetch_external_id(hrid: hrid)).to eq(external_id)
    end

    context 'when no results are found' do
      let(:search_instance_response) do
        { 'totalRecords' => 0,
          'instances' => [] }
      end

      it 'raises ResourceNotFound' do
        expect do
          inventory.fetch_external_id(hrid: hrid)
        end.to raise_error(FolioClient::ResourceNotFound,
                           "No matching instance found for #{hrid}")
      end
    end

    context 'when multiple results are found' do
      let(:search_instance_response) do
        { 'totalRecords' => 2,
          'instances' => [nil, nil] }
      end

      it 'raises MultipleResourcesFound' do
        expect do
          inventory.fetch_external_id(hrid: hrid)
        end.to raise_error(FolioClient::MultipleResourcesFound,
                           "Expected 1 record for #{hrid}, but found 2")
      end
    end
  end

  describe '#fetch_instance_info' do
    let(:hrid) { 'in00000000067' }
    let(:external_id) { '5108040a-65bc-40ed-bd50-265958301ce4' }
    let(:instance_info_response) do
      { 'id' => '5108040a-65bc-40ed-bd50-265958301ce4',
        '_version' => '18',
        'hrid' => 'in00000000067',
        'source' => 'MARC',
        'title' => 'TOPICS IN CONVEX OPTIMIZATION FOR MACHINE LEARNING / Youngsuk Park.',
        'administrativeNotes' => ['https://etd.stanford.edu/view/0000007573'],
        'identifiers' => [{ 'identifierTypeId' => '7e591197-f335-4afb-bc6d-a6d76ca3bace',
                            'value' => 'dorcg532dg5405' }],
        'contributors' =>
        [{ 'contributorNameTypeId' => '2b94c631-fca9-4892-a730-03ee529ffe2a', 'name' => 'Park, Youngsuk,',
           'contributorTypeText' => 'author.', 'primary' => true }],
        'instanceTypeId' => '6312d172-f0cf-40f6-b27d-9fa8feaf332f',
        'languages' => ['eng'],
        'notes' =>
        [{ 'instanceNoteTypeId' => '6a2533a7-4de2-4e64-8466-074c2fa9308c',
           'note' => 'Submitted to the Department of Electrical Engineering', 'staffOnly' => false }],
        'statusId' => '26f5208e-110a-4394-be29-1569a8c84a65',
        'statusUpdatedDate' => '2023-03-02T14:12:30.101+0000',
        'metadata' =>
        { 'createdDate' => '2023-03-02T14:12:30.100+00:00', 'createdByUserId' => '297649ab-3f9e-5ece-91a3-25cf700062ae',
          'updatedDate' => '2023-03-14T04:44:48.683+00:00', 'updatedByUserId' => '297649ab-3f9e-5ece-91a3-25cf700062ae' } }
    end
    let(:search_instance_response) do
      { 'totalRecords' => 1,
        'instances' =>
        [{ 'id' => external_id,
           'title' => 'TOPICS IN CONVEX OPTIMIZATION FOR MACHINE LEARNING / Youngsuk Park.',
           'contributors' => [{ 'name' => 'Park, Youngsuk,',
                                'contributorNameTypeId' => '2b94c631-fca9-4892-a730-03ee529ffe2a', 'primary' => true }],
           'publication' => [{ 'publisher' => '[Stanford University]', 'dateOfPublication' => '2020' },
                             { 'dateOfPublication' => '©2020' }] }] }
    end

    before do
      stub_request(:get, "#{url}/search/instances?query=hrid==#{hrid}")
        .to_return(status: 200, body: search_instance_response.to_json)
      stub_request(:get, "#{url}/inventory/instances/#{external_id}")
        .to_return(status: 200, body: instance_info_response.to_json)
    end

    it 'fetches info about the inventory instance if given an external ID for an extant record' do
      expect(inventory.fetch_instance_info(external_id: external_id)).to eq(instance_info_response)
    end

    it 'fetches info about the inventory instance if given an HRID for an extant record' do
      expect(inventory.fetch_instance_info(hrid: hrid)).to eq(instance_info_response)
    end

    it 'raises an error if neither type of ID is provided' do
      expect do
        inventory.fetch_instance_info
      end.to raise_error(ArgumentError, 'must pass exactly one of external_id or HRID')
    end

    it 'raises an error if both types of ID are provided' do
      expect do
        inventory.fetch_instance_info(external_id: external_id,
                                      hrid: hrid)
      end.to raise_error(ArgumentError, 'must pass exactly one of external_id or HRID')
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
      result = inventory.fetch_location(location_id: location_id)
      expect(result).to eq(location_response)
      expect(result['campusId']).to eq('b595d838-b1d5-409e-86ac-af3b41bde0be')
    end

    context 'when location is not found' do
      before do
        stub_request(:get, "#{url}/locations/#{location_id}")
          .to_return(status: 404, body: 'location not found')
      end

      it 'raises ResourceNotFound' do
        expect do
          inventory.fetch_location(location_id: location_id)
        end.to raise_error(FolioClient::ResourceNotFound,
                           /Endpoint not found or resource does not exist/)
      end
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
      result = inventory.fetch_holdings(hrid: hrid)
      expect(result).to eq(holdings_array)
      expect(result.length).to eq(2)
    end

    it 'includes permanentLocationId in holdings' do
      result = inventory.fetch_holdings(hrid: hrid)
      expect(result.first['permanentLocationId']).to eq('d9cd0bed-1b49-4b5e-a7bd-064b8d177231')
    end

    it 'includes discoverySuppress field in holdings' do
      result = inventory.fetch_holdings(hrid: hrid)
      expect(result.first['discoverySuppress']).to be false
      expect(result.last['discoverySuppress']).to be true
    end

    context 'when instance has no holdings' do
      let(:search_instance_response) do
        {
          'totalRecords' => 1,
          'instances' => [
            {
              'id' => '5108040a-65bc-40ed-bd50-265958301ce4',
              'title' => 'TOPICS IN CONVEX OPTIMIZATION FOR MACHINE LEARNING',
              'holdings' => []
            }
          ]
        }
      end

      it 'returns an empty array' do
        expect(inventory.fetch_holdings(hrid: hrid)).to eq([])
      end
    end

    context 'when holdings key is missing' do
      let(:search_instance_response) do
        {
          'totalRecords' => 1,
          'instances' => [
            {
              'id' => '5108040a-65bc-40ed-bd50-265958301ce4',
              'title' => 'TOPICS IN CONVEX OPTIMIZATION FOR MACHINE LEARNING'
            }
          ]
        }
      end

      it 'returns an empty array' do
        expect(inventory.fetch_holdings(hrid: hrid)).to eq([])
      end
    end

    context 'when no instance is found' do
      let(:search_instance_response) do
        {
          'totalRecords' => 0,
          'instances' => []
        }
      end

      it 'raises ResourceNotFound' do
        expect do
          inventory.fetch_holdings(hrid: hrid)
        end.to raise_error(FolioClient::ResourceNotFound,
                           "No matching instance found for #{hrid}")
      end
    end

    context 'when multiple instances are found' do
      let(:search_instance_response) do
        {
          'totalRecords' => 2,
          'instances' => [nil, nil]
        }
      end

      it 'raises MultipleResourcesFound' do
        expect do
          inventory.fetch_holdings(hrid: hrid)
        end.to raise_error(FolioClient::MultipleResourcesFound,
                           "Expected 1 record for #{hrid}, but found 2")
      end
    end
  end
end
