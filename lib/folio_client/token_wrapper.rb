# frozen_string_literal: true

class FolioClient
  # Wraps API operations to request new access token if expired
  class TokenWrapper
    def self.refresh(config, connection)
      yield
    rescue UnexpectedResponse::UnauthorizedError
      config.token = Authenticator.token(config.login_params, connection)
      yield
    end
  end
end
