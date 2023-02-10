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
end
