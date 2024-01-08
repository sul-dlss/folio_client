# frozen_string_literal: true

class FolioClient
  # Fetch a token from the Folio API using login_params
  class Authenticator
    def self.token(login_params, connection, legacy_auth, cookie_jar)
      new(login_params, connection, legacy_auth, cookie_jar).token
    end

    def initialize(login_params, connection, legacy_auth, cookie_jar)
      @login_params = login_params
      @connection = connection
      @legacy_auth = legacy_auth
      @cookie_jar = cookie_jar
    end

    # Request an access_token
    # rubocop:disable Metrics/AbcSize
    def token
      response = connection.post(login_endpoint, login_params.to_json)

      UnexpectedResponse.call(response) unless response.success?

      # remove legacy_auth once new tokens enabled on Poppy
      if legacy_auth
        JSON.parse(response.body)['okapiToken']
      else
        access_cookies = cookie_jar.cookies.select { |cookie| cookie.name == 'folioAccessToken' }
        access_cookies[0].value
      end
    end
    # rubocop:enable Metrics/AbcSize

    attr_reader :login_params, :connection, :legacy_auth, :cookie_jar

    private

    def login_endpoint
      return '/authn/login-with-expiry' unless legacy_auth

      '/authn/login'
    end
  end
end
