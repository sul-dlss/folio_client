# frozen_string_literal: true

class FolioClient
  # Fetch a token from the Folio API using login_params
  class Authenticator
    LOGIN_ENDPOINT = '/authn/login-with-expiry'

    # Request an access_token
    #
    # @raise [UnauthorizedError] if the response is not successful or if the
    # @return [String] the access token
    def self.refresh_token!
      response = FolioClient.connection.post(LOGIN_ENDPOINT, FolioClient.config.login_params.to_json)

      UnexpectedResponse.call(response) unless response.success?

      access_cookie = FolioClient.cookie_jar.cookies.find { |cookie| cookie.name == 'folioAccessToken' }

      # NOTE: The client typically delegates raising exceptions (based on HTTP
      #       responses) to the UnexpectedResponse class, but this call in
      #       Authenticator is a one-off, unlike any other in the app, so we
      #       allow it to customize its exception handling.
      raise UnauthorizedError, "Problem with folioAccessToken cookie: #{response.headers}, #{response.body}" unless access_cookie

      access_cookie.value
    end
  end
end
