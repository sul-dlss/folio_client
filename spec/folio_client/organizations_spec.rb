# frozen_string_literal: true

RSpec.describe FolioClient::Organizations do
  subject(:organizations) do
    described_class.new(client)
  end

  let(:args) { { url: url, login_params: login_params, okapi_headers: okapi_headers } }
  let(:url) { 'https://folio.example.org' }
  let(:login_params) { { username: 'username', password: 'password' } }
  let(:okapi_headers) { { some_bogus_headers: 'here' } }
  let(:token) { 'a_long_silly_token' }
  let(:client) { FolioClient.configure(**args) }
  let(:id) { 'some_long_id_that_is_long' }
  let(:query) { '"active=="true"' }

  before do
    stub_request(:post, "#{url}/authn/login")
      .to_return(status: 200, body: "{\"okapiToken\" : \"#{token}\"}")
  end

  context 'when looking up a list of organizations' do
    context 'when a query is specified' do
      before do
        stub_request(:get, "#{url}/organizations/organizations?lang=en&limit=10000&offset=0&query=#{query}")
          .to_return(status: 200, body: organization_response.to_json)
      end

      let(:organization_response) do
        { 'totalRecords' => 1,
          'organizations' => [
            { 'id' => '12345',
              'name' => 'Training videos' }
          ] }
      end

      it 'returns the organization list' do
        expect(organizations.fetch_list(query: query)).to eq(organization_response)
      end
    end

    context 'when a query is not specified' do
      before do
        stub_request(:get, "#{url}/organizations/organizations?lang=en&limit=10000&offset=0")
          .to_return(status: 200, body: organization_response.to_json)
      end

      let(:organization_response) do
        { 'totalRecords' => 1,
          'organizations' => [
            { 'id' => '12345',
              'name' => 'Training videos' }
          ] }
      end

      it 'returns the organization list' do
        expect(organizations.fetch_list).to eq(organization_response)
      end
    end
  end

  context 'when looking up a list of organization interfaces' do
    context 'when a query is specified' do
      before do
        stub_request(:get, "#{url}/organizations-storage/interfaces?lang=en&limit=10000&offset=0&query=#{query}")
          .to_return(status: 200, body: organization_interface_response.to_json)
      end

      let(:organization_interface_response) do
        { 'totalRecords' => 1,
          'interfaces' => [
            { 'id' => '12345',
              'description' => 'Training videos' }
          ] }
      end

      it 'returns the organization list' do
        expect(organizations.fetch_interface_list(query: query)).to eq(organization_interface_response)
      end
    end

    context 'when a query is not specified' do
      before do
        stub_request(:get, "#{url}/organizations-storage/interfaces?lang=en&limit=10000&offset=0")
          .to_return(status: 200, body: organization_interface_response.to_json)
      end

      let(:organization_interface_response) do
        { 'totalRecords' => 1,
          'interfaces' => [
            { 'id' => '12345',
              'description' => 'Training videos' }
          ] }
      end

      it 'returns the organization list' do
        expect(organizations.fetch_interface_list).to eq(organization_interface_response)
      end
    end
  end

  context 'when looking up details of a specific organization interfaces' do
    before do
      stub_request(:get, "#{url}/organizations-storage/interfaces/#{id}?lang=en")
        .to_return(status: 200, body: organization_interface_detail_response.to_json)
    end

    let(:organization_interface_detail_response) do
      { 'id' => id,
        'name' => 'tes',
        'type' => ['Invoices'],
        'metadata' =>
         { 'createdDate' => '2023-02-16T22:27:51.515+00:00',
           'createdByUserId' => '38524916-598d-4edf-a2ef-04bba7e78ad6',
           'updatedDate' => '2023-02-16T22:27:51.515+00:00',
           'updatedByUserId' => '38524916-598d-4edf-a2ef-04bba7e78ad6' } }
    end

    it 'returns the organization interface details' do
      expect(organizations.fetch_interface_details(id: id)).to eq(organization_interface_detail_response)
    end
  end
end
