# frozen_string_literal: true

class FolioClient
  # Fetch a token from the Folio API using login_params
  class Authenticator
    def self.token
      new.token
    end

    # Request an access_token
    def token # rubocop:disable Metrics/AbcSize
      response = FolioClient.connection.post(login_endpoint, FolioClient.config.login_params.to_json)

      UnexpectedResponse.call(response) unless response.success?

      # remove legacy_auth once new tokens enabled on Poppy
      if FolioClient.config.legacy_auth
        JSON.parse(response.body)['okapiToken']
      else
        access_cookie = FolioClient.cookie_jar.cookies.find { |cookie| cookie.name == 'folioAccessToken' }

        raise StandardError, "Problem with folioAccessToken cookie: #{response.headers}, #{response.body}" unless access_cookie

        access_cookie.value
      end
    end

    private

    def login_endpoint
      return '/authn/login-with-expiry' unless FolioClient.config.legacy_auth

      '/authn/login'
    end
  end
end
