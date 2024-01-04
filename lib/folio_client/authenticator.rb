# frozen_string_literal: true

class FolioClient
  # Fetch a token from the Folio API using login_params
  class Authenticator
    def self.token(login_params, connection)
      new(login_params, connection).token
    end

    def initialize(login_params, connection)
      @login_params = login_params
      @connection = connection
    end

    # Request an access_token
    def token
      response = connection.post('/authn/login', login_params.to_json)

      UnexpectedResponse.call(response) unless response.success?

      JSON.parse(response.body)['okapiToken']
    end

    attr_reader :login_params, :connection
  end
end
