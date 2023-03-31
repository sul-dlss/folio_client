# frozen_string_literal: true

RSpec.describe FolioClient::Authenticator do
  let(:args) { {url: url, login_params: login_params, okapi_headers: okapi_headers} }
  let(:url) { "https://folio.example.org" }
  let(:login_params) { {username: "username", password: "password"} }
  let(:okapi_headers) { {some_bogus_headers: "here"} }
  let(:token) { "a_long_silly_token" }
  let(:connection) { FolioClient.configure(**args).connection }
  let(:http_status) { 200 }
  let(:http_body) { "{\"okapiToken\" : \"#{token}\"}" }

  before do
    stub_request(:post, "#{url}/authn/login").to_return(status: http_status, body: http_body)
  end

  describe ".token" do
    let(:instance) { described_class.new(login_params, connection) }

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

    context "when correct credentials" do
      it "parses the token from the response" do
        expect(authenticator.token).to eq(token)
      end
    end

    context "when incorrect credentials" do
      let(:http_status) { 401 }
      let(:http_body) { "{\"error\" : \"get bent\"}" }

      it "raises an unauthorized error" do
        expect { authenticator.token }.to raise_error(FolioClient::UnauthorizedError)
      end
    end

    context "when client lacks privileges" do
      let(:http_status) { 403 }
      let(:http_body) { "{\"error\" : \"get bent\"}" }

      it "raises a forbidden error" do
        expect { authenticator.token }.to raise_error(FolioClient::ForbiddenError)
      end
    end

    context "when client sends invalid request" do
      let(:http_status) { 422 }
      let(:http_body) { "{\"error\" : \"get bent\"}" }

      it "raises a validation error" do
        expect { authenticator.token }.to raise_error(FolioClient::ValidationError)
      end
    end

    context "when service is unavailable" do
      let(:http_status) { 500 }
      let(:http_body) { "{\"error\" : \"get bent\"}" }

      it "raises a service unavailable exception" do
        expect { authenticator.token }.to raise_error(FolioClient::ServiceUnavailable)
      end
    end

    context "when the service returns a 409 conflict error" do
      let(:http_status) { 409 }
      let(:http_body) { "{\"error\" : \"get bent\"}" }

      it "raises a conflict error exception" do
        expect { authenticator.token }.to raise_error(FolioClient::ConflictError)
      end
    end

    context "when the truly unexpected happens" do
      let(:http_status) { 666 }
      let(:http_body) { "{\"error\" : \"huh?\"}" }

      it "raises a standard error" do
        expect { authenticator.token }.to raise_error(StandardError, /Unexpected response/)
      end
    end
  end
end
