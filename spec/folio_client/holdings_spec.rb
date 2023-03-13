# frozen_string_literal: true

RSpec.describe FolioClient::Holdings do
  let(:holdings_client) { described_class.new(client, instance_id: instance_id) }
  let(:args) { {url: url, login_params: login_params, okapi_headers: okapi_headers} }
  let(:url) { "https://folio.example.org" }
  let(:login_params) { {username: "username", password: "password"} }
  let(:okapi_headers) { {some_bogus_headers: "here"} }
  let(:token) { "a_long_silly_token" }
  let(:client) { FolioClient.configure(**args) }

  let(:instance_id) { "99a6d818-d523-42f3-9844-81cf3187dbad" }
  let(:holdings_type_id) { "996f93e2-5b5e-4cf2-9168-33ced1f95eed" }
  let(:permanent_location_id) { "1b14e21c-8d47-45c7-bc49-456a0086422b" }

  before do
    stub_request(:post, "#{url}/authn/login")
      .to_return(status: 200, body: "{\"okapiToken\" : \"#{token}\"}")
    allow(DateTime).to receive(:now).and_return(DateTime.parse("2023-03-01T11:17:25-05:00"))
  end

  describe ".create" do
    let(:create) { holdings_client.create(permanent_location_id: permanent_location_id, holdings_type_id: holdings_type_id) }

    context "when successful" do
      let(:response_body) do
        {
          "id" => "581f6289-001f-49d1-bab7-035f4d878cbd",
          "_version" => 1,
          "hrid" => "ho00000000065",
          "holdingsTypeId" => "996f93e2-5b5e-4cf2-9168-33ced1f95eed"
        }
      end

      before do
        stub_request(:post, "#{url}/holdings-storage/holdings")
          .with(
            body: {
              instanceId: instance_id,
              permanentLocationId: permanent_location_id,
              holdingsTypeId: holdings_type_id
            }.to_json
          )
          .to_return(status: 201, body: response_body.to_json)
      end

      it "returns response body" do
        expect(create).to eq(response_body)
      end
    end

    context "when error" do
      let(:response_body) do
        {errors: [{message: "Cannot set holdings_record.permanentlocationid = 1b14e21c-8d47-45c7-bc49-456a0086422c because it does not exist in location.id.",
                   type: "1",
                   code: "-1",
                   parameters: [{key: "holdings_record.permanentlocationid",
                                 value: "1b14e21c-8d47-45c7-bc49-456a0086422c"}]}]}
      end

      before do
        stub_request(:post, "#{url}/holdings-storage/holdings")
          .with(
            body: {
              instanceId: instance_id,
              permanentLocationId: permanent_location_id,
              holdingsTypeId: holdings_type_id
            }.to_json
          )
          .to_return(status: 422, body: response_body.to_json)
      end

      it "raise" do
        expect { create }.to raise_error(FolioClient::ValidationError, /Cannot set holdings_record.permanentlocationid/)
      end
    end
  end
end
