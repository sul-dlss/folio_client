# frozen_string_literal: true

class FolioClient
  # Fetch a token from the Folio API using login_params
  class Authenticator
    def self.token
      new.token
    end

    # Request an access_token
    def token
      response = FolioClient.connection.post(login_endpoint, FolioClient.config.login_params.to_json)

      UnexpectedResponse.call(response) unless response.success?

      access_cookie = FolioClient.cookie_jar.cookies.find { |cookie| cookie.name == 'folioAccessToken' }

      # NOTE: The client typically delegates raising exceptions (based on HTTP
      #       responses) to the UnexpectedResponse class, but this call in
      #       Authenticator is a one-off, unlike any other in the app, so we
      #       allow it to customize its exception handling.
      raise UnauthorizedError, "Problem with folioAccessToken cookie: #{response.headers}, #{response.body}" unless access_cookie

      access_cookie.value
    end

    private

    def login_endpoint
      '/authn/login-with-expiry'
    end
  end
end
