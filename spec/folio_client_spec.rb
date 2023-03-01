# frozen_string_literal: true

RSpec.describe FolioClient do
  subject(:client) do
    described_class.configure(**args)
  end

  let(:args) { {url: url, login_params: login_params, okapi_headers: okapi_headers} }
  let(:url) { "https://folio.example.org" }
  let(:login_params) { {username: "username", password: "password"} }
  let(:okapi_headers) { {some_bogus_headers: "here"} }
  let(:token) { "a_long_silly_token" }

  before do
    stub_request(:post, "#{url}/authn/login")
      .to_return(status: 200, body: "{\"okapiToken\" : \"#{token}\"}")
  end

  it "has a version number" do
    expect(FolioClient::VERSION).not_to be nil
  end

  it "has singleton behavior" do
    expect(described_class.instance).to be_a(described_class)
  end

  describe ".configure" do
    it "stores passed in values in the config" do
      expect(client.config.login_params).to eq(login_params)
      expect(client.config.url).to eq(url)
      expect(client.config.okapi_headers).to eq(okapi_headers)
    end

    it "stores the fetched token in the config" do
      expect(client.config.token).to eq(token)
    end
  end

  describe "#get" do
    let(:path) { "some_path" }
    let(:response) { {some: "response"}.to_json }

    before do
      stub_request(:get, "#{url}/#{path}?id=5")
        .to_return(status: 200, body: response.to_json)
    end

    it "calls the API with a get" do
      expect(client.get(path, {id: 5})).to eq(response)
    end
  end

  describe "#post" do
    let(:path) { "some_path" }
    let(:response) { {some: "response"}.to_json }

    before do
      stub_request(:post, "#{url}/#{path}")
        .to_return(status: 200, body: response.to_json)
    end

    it "calls the API with a post" do
      expect(client.post(path, {id: 5})).to eq(response)
    end
  end

  describe ".fetch_hrid" do
    let(:barcode) { "123456" }

    before do
      allow(described_class.instance).to receive(:fetch_hrid).with(barcode: barcode)
    end

    it "invokes instance#fetch_hrid" do
      client.fetch_hrid(barcode: barcode)
      expect(client.instance).to have_received(:fetch_hrid).with(barcode: barcode)
    end
  end

  describe ".has_instance_status?" do
    let(:hrid) { "a12854819" }
    let(:status_id) { "1a2b3c4d-1234" }

    before do
      allow(described_class.instance).to receive(:has_instance_status?).with(hrid: hrid, status_id: status_id)
    end

    it "invokes instance#has_instance_status?" do
      client.has_instance_status?(hrid: hrid, status_id: status_id)
      expect(client.instance).to have_received(:has_instance_status?).with(hrid: hrid, status_id: status_id)
    end
  end

  describe "#has_instance_status?" do
    let(:hrid) { "a12854819" }
    let(:status_id) { "1a2b3c4d-1234" }
    let(:inventory) { instance_double(described_class::Inventory) }

    before do
      allow(described_class::Inventory).to receive(:new).and_return(inventory)
      allow(inventory).to receive(:has_instance_status?)
    end

    it "invokes Inventory#has_instance_status?" do
      client.public_send(:has_instance_status?, hrid: hrid, status_id: status_id)
      expect(inventory).to have_received(:has_instance_status?).once
    end
  end

  # Tests the TokenWrapper that requests a new token, with a method that might first encounter the error
  context "when token is expired" do
    let(:inventory) { instance_double(FolioClient::Inventory, fetch_hrid: nil) }
    let(:hrid) { "in56789" }
    let(:expired_token) { "expired_token" }
    let(:new_token) { "new_token" }
    let(:barcode) { "123456" }
    let(:instance_uuid) { "d71e654b-ca5e-44c0-9621-ae86ffd528d3" }
    let(:inventory_instance_response) {
      {"id" => instance_uuid,
       "_version" => "1",
       "hrid" => hrid,
       "source" => "FOLIO",
       "title" => "Training videos",
       "isBoundWith" => false,
       "contributors" => [],
       "publication" => [],
       "electronicAccess" => [],
       "instanceTypeId" => "225faa14-f9bf-4ecd-990d-69433c912434",
       "statusId" => "2a340d34-6b70-443a-bb1b-1b8d1c65d862",
       "statusUpdatedDate" => "2023-02-10T21:19:22.285+0000",
       "metadata" => {},
       "succeedingTitles" => []}
    }
    let(:search_instance_response) {
      {"totalRecords" => 1,
       "instances" => [
         {"id" => instance_uuid,
          "title" => "Training videos",
          "contributors" => [{"name" => "Person"}],
          "isBoundWith" => false,
          "holdings" => []}
       ]}
    }

    before do
      stub_request(:post, "#{url}/authn/login")
        .to_return(
          {status: 200, body: "{\"okapiToken\" : \"#{expired_token}\"}"},
          {status: 200, body: "{\"okapiToken\" : \"#{new_token}\"}"}
        )
      stub_request(:get, "#{url}/search/instances?query=items.barcode==#{barcode}")
        .with(headers: {"x-okapi-token": expired_token})
        .to_return(
          {status: 401, body: "invalid authN token"}
        )
      stub_request(:get, "#{url}/search/instances?query=items.barcode==#{barcode}")
        .with(headers: {"x-okapi-token": new_token})
        .to_return(
          {status: 200, body: search_instance_response.to_json}
        )
      stub_request(:get, "#{url}/inventory/instances/#{instance_uuid}")
        .with(headers: {"x-okapi-token": new_token})
        .to_return(status: 200, body: inventory_instance_response.to_json)
    end

    it "fetches new token and retries" do
      expect { client.fetch_hrid(barcode: barcode) }
        .to change(client.config, :token)
        .from(expired_token)
        .to(new_token)
    end
  end
end
