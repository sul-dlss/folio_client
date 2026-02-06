# frozen_string_literal: true

RSpec.describe FolioClient::Users do
  subject(:users) do
    described_class.new
  end

  let(:args) { { url: url, login_params: login_params, okapi_headers: okapi_headers } }
  let(:url) { 'https://folio.example.org' }
  let(:login_params) { { username: 'username', password: 'password' } }
  let(:okapi_headers) { { some_bogus_headers: 'here' } }
  let(:token) { 'a_long_silly_token' }
  let(:cookie_headers) do
    { 'Set-Cookie': "folioAccessToken=#{token}; Expires=Fri, 22 Sep 2050 14:30:10 GMT; Path=/; Secure; HTTPOnly; SameSite=None" }
  end
  let(:client) { FolioClient.instance }
  let(:id) { 'some_long_id_that_is_long' }
  let(:query) { '"active=="true"' }
  let(:users_response) do
    { 'users' =>
    [{ 'username' => 'user',
       'id' => '6cf89272-3d9f-43f1-af36-33e2c9a0516b',
       'externalSystemId' => '05733590',
       'barcode' => '2558668146',
       'active' => true,
       'patronGroup' => '503281cd-6c26-400f-b620-14c08943697c',
       'departments' => ['e85216c6-b39e-477e-a094-de10b941837d'],
       'proxyFor' => [],
       'personal' =>
       { 'lastName' => 'Last',
         'firstName' => 'First',
         'middleName' => 'Middle',
         'email' => 'foliotesting@lists.stanford.edu',
         'phone' => '(508) 564-0051',
         'addresses' =>
         [{ 'countryId' => 'US',
            'addressLine1' => '123 Test St',
            'city' => 'Palo Alto',
            'region' => 'California',
            'postalCode' => '94035',
            'addressTypeId' => '93d3588d-499b-45d0-9bc7-ac73c3a19880',
            'primaryAddress' => true },
          { 'countryId' => 'US',
            'addressLine1' => '473 Via Ortega,',
            'city' => 'Stanford',
            'region' => 'California',
            'postalCode' => '94305',
            'addressTypeId' => '1c4b215f-f669-4e9b-afcd-ebc0e273a34e',
            'primaryAddress' => false }],
         'preferredContactTypeId' => '002' },
       'enrollmentDate' => '2023-09-01T00:00:00.000+00:00',
       'createdDate' => '2023-10-05T12:30:06.244+00:00',
       'updatedDate' => '2023-10-05T12:30:06.244+00:00',
       'metadata' =>
       { 'createdDate' => '2023-08-10T23:34:05.812+00:00',
         'createdByUserId' => '58d0aaf6-dcda-4d5e-92da-012e6b7dd766',
         'updatedDate' => '2023-10-05T12:30:06.238+00:00',
         'updatedByUserId' => '58d0aaf6-dcda-4d5e-92da-012e6b7dd766' },
       'customFields' => { 'mobileid' => '0515252', 'affiliation' => 'faculty', 'proximitychipid' => '0493670',
                           'department' => 'Oceans' } }],
      'totalRecords' => 1,
      'resultInfo' => { 'totalRecords' => 1, 'facets' => [], 'diagnostics' => [] } }
  end

  before do
    FolioClient.configure(**args)

    stub_request(:post, "#{url}/authn/login-with-expiry")
      .to_return(status: 200, headers: cookie_headers)
  end

  context 'when looking up a list of users' do
    context 'when a query is specified' do
      before do
        stub_request(:get, "#{url}/users?lang=en&limit=10000&offset=0&query=#{query}")
          .to_return(status: 200, body: users_response.to_json)
      end

      it 'returns the user list' do
        expect(users.fetch_list(query: query)).to eq(users_response)
      end
    end

    context 'when a query is not specified' do
      before do
        stub_request(:get, "#{url}/users?lang=en&limit=10000&offset=0")
          .to_return(status: 200, body: users_response.to_json)
      end

      it 'returns the user list' do
        expect(users.fetch_list).to eq(users_response)
      end
    end
  end

  context 'when looking up details of a specific user' do
    before do
      stub_request(:get, "#{url}/users/#{id}?lang=en")
        .to_return(status: 200, body: user_detail_response.to_json)
    end

    let(:user_detail_response) do
      { 'username' => 'abcdef',
        'id' => 'f07a11f5-47a6-471d-8c80-94d2bb1456fd',
        'externalSystemId' => '19608544',
        'active' => false,
        'departments' => ['e8h216c6-b39e-477e-a094-de10b941837d'],
        'proxyFor' => [],
        'personal' => { 'lastName' => 'Testing', 'firstName' => 'Last', 'middleName' => 'V', 'addresses' => [],
                        'preferredContactTypeId' => '002' },
        'createdDate' => '2023-10-07T09:14:19.481+00:00',
        'updatedDate' => '2023-10-07T09:14:19.481+00:00',
        'metadata' =>
       { 'createdDate' => '2023-09-07T09:02:30.936+00:00',
         'createdByUserId' => '58d0aaf6-dcda-4d5e-92da-012e6b7dd766',
         'updatedDate' => '2023-10-07T09:14:19.478+00:00',
         'updatedByUserId' => '58d0aaf6-dcda-4d5e-92da-012e6b7dd766' },
        'customFields' => { 'affiliation' => 'affiliate:sponsored' } }
    end

    it 'returns the user details' do
      expect(users.fetch_user_details(id: id)).to eq(user_detail_response)
    end
  end
end
