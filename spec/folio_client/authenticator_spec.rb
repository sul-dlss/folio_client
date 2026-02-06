# frozen_string_literal: true

RSpec.describe FolioClient::Authenticator do
  let(:args) { { url: url, login_params: login_params, okapi_headers: okapi_headers } }
  let(:url) { 'https://folio.example.org' }
  let(:login_params) { { username: 'username', password: 'password' } }
  let(:okapi_headers) { { some_bogus_headers: 'here' } }
  let(:connection) { FolioClient.connection }
  let(:http_body) { "{\"okapiToken\" : \"#{token}\"}" }
  let(:cookie_jar) { FolioClient.cookie_jar }
  let(:http_status) { 201 }
  let(:token) { 'a_token_4567' }
  # rubocop:disable Layout/LineLength
  let(:headers) do
    { 'Set-Cookie': 'folioAccessToken=a_token_4567; Max-Age=600; Expires=Fri, 22 Sep 2050 14:30:10 GMT; Path=/; Secure; HTTPOnly; SameSite=None, folioRefreshToken=blah; Max-Age=604800; Expires=Fri, 29 Sep 2050 14:20:10 GMT; Max-Age=604800; Path=/; Secure; HTTPOnly; SameSite=None' }
  end
  # Faraday concatenates multiple same headers using a comma https://github.com/lostisland/faraday/issues/1120
  # rubocop:enable Layout/LineLength

  before do
    FolioClient.configure(**args)
    stub_request(:post, "#{url}/authn/login-with-expiry").to_return(status: http_status, headers: headers)
  end

  describe '.token' do
    let(:instance) { described_class.new }

    before do
      allow(described_class).to receive(:new).and_return(instance)
      allow(instance).to receive(:token)
    end

    it 'invokes #token on a new instance' do
      described_class.token
      expect(instance).to have_received(:token).once
    end
  end

  describe '#token' do
    subject(:authenticator) { described_class.new }

    context 'when correct credentials' do
      it 'parses the token from the response' do
        expect(authenticator.token).to eq(token)
      end
    end

    context 'when incorrect credentials' do
      let(:http_status) { 401 }
      let(:http_body) { '{"error" : "get bent"}' }

      it 'raises an unauthorized error' do
        expect { authenticator.token }.to raise_error(FolioClient::UnauthorizedError)
      end
    end

    context 'when client lacks privileges' do
      let(:http_status) { 403 }
      let(:http_body) { '{"error" : "get bent"}' }

      it 'raises a forbidden error' do
        expect { authenticator.token }.to raise_error(FolioClient::ForbiddenError)
      end
    end

    context 'when client sends invalid request' do
      let(:http_status) { 422 }
      let(:http_body) { '{"error" : "get bent"}' }

      it 'raises a validation error' do
        expect { authenticator.token }.to raise_error(FolioClient::ValidationError)
      end
    end

    context 'when service is unavailable' do
      let(:http_status) { 500 }
      let(:http_body) { '{"error" : "get bent"}' }

      it 'raises a service unavailable exception' do
        expect { authenticator.token }.to raise_error(FolioClient::ServiceUnavailable)
      end
    end

    context 'when the service returns a 409 conflict error' do
      let(:http_status) { 409 }
      let(:http_body) { '{"error" : "get bent"}' }

      it 'raises a conflict error exception' do
        expect { authenticator.token }.to raise_error(FolioClient::ConflictError)
      end
    end

    context 'when the truly unexpected happens' do
      let(:http_status) { 666 }
      let(:http_body) { '{"error" : "huh?"}' }

      it 'raises a standard error' do
        expect { authenticator.token }.to raise_error(StandardError, /Unexpected response/)
      end
    end

    context 'when there is a problem with the cookie' do
      let(:http_status) { 201 }
      let(:token) { nil }
      let(:headers) do
        { 'Set-Cookie': 'folioRefreshToken=blah; Max-Age=604800; Expires=Fri, 29 Sep 2020 14:20:10 GMT; Max-Age=604800; Path=/; Secure; HTTPOnly;' }
      end

      before do
        stub_request(:post, "#{url}/authn/login-with-expiry").to_return(status: http_status, headers: headers)
      end

      it 'raises an error' do
        FolioClient.cookie_jar.clear
        expect { authenticator.token }.to raise_error(StandardError)
      end
    end
  end
end
