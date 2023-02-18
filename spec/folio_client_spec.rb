# frozen_string_literal: true

RSpec.describe FolioClient do
  subject(:client) do
    described_class.configure(**args)
  end

  let(:args) do
    {
      url:,
      login_params:,
      okapi_headers:
    }
  end
  let(:url) { "https://folio.example.org" }
  let(:login_params) { { username: "username", password: "password" } }
  let(:okapi_headers) { { some_bogus_headers: "here" } }
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
    let(:response) { { some: "response" }.to_json }

    before do
      stub_request(:get, "#{url}/#{path}?id=5")
        .to_return(status: 200, body: response.to_json)
    end

    it "calls the API with a get" do
      expect(client.get(path, { id: 5 })).to eq(response)
    end
  end

  describe "#post" do
    let(:path) { "some_path" }
    let(:response) { { some: "response" }.to_json }

    before do
      stub_request(:post, "#{url}/#{path}")
        .to_return(status: 200, body: response.to_json)
    end

    it "calls the API with a post" do
      expect(client.post(path, { id: 5 })).to eq(response)
    end
  end

  describe ".fetch_hrid" do
    let(:barcode) { "123456" }

    before do
      allow(described_class.instance).to receive(:fetch_hrid).with(barcode:)
    end

    it "invokes instance#fetch_hrid" do
      client.fetch_hrid(barcode:)
      expect(client.instance).to have_received(:fetch_hrid).with(barcode:)
    end
  end

  # Tests the TokenWrapper that requests a new token, with a method that might first encounter the error
  context "when token is expired" do
    let(:inventory) { instance_double(FolioClient::Inventory, fetch_hrid: nil) }
    let(:hrid) { "in56789" }
    let(:expired_token) { "expired_token" }
    let(:new_token) { "new_token" }

    before do
      allow(FolioClient::Inventory).to receive(:new).and_return(inventory)
      allow(FolioClient::Authenticator).to receive(:token).and_return(expired_token, new_token)
      response_values = [:raise, hrid]
      allow(inventory).to receive(:fetch_hrid).twice do
        v = response_values.shift
        (v == :raise) ? raise(FolioClient::UnexpectedResponse::UnauthorizedError) : v
      end
    end

    it "fetches new token and retries" do
      expect { client.fetch_hrid(barcode: "1234") }
        .to change(client.config, :token)
        .from(expired_token)
        .to(new_token)
    end
  end
end
