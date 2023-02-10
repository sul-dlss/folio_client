# frozen_string_literal: true

RSpec.describe FolioClient::Authenticator do
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
  let(:connection) { FolioClient.configure(**args).connection }

  before do
    stub_request(:post, "#{url}/authn/login")
      .to_return(status: 200, body: "{\"okapiToken\" : \"#{token}\"}")
  end

  describe ".token" do
    let(:instance) do
      described_class.new(login_params, connection)
    end

    before do
      allow(described_class).to receive(:new).and_return(instance)
      allow(instance).to receive(:token)
    end

    it "invokes #token on a new instance" do
      described_class.token(login_params, connection)
      expect(instance).to have_received(:token).once
    end
  end

  describe "#token" do
    subject(:authenticator) { described_class.new(login_params, connection) }

    it "parses the token from the response" do
      expect(authenticator.token).to eq(token)
    end
  end
end
