# frozen_string_literal: true

class FolioClient
  # Handles unexpected responses when communicating with Folio
  class UnexpectedResponse
    # @param [Faraday::Response] response
    def self.call(response)
      case response.status
      when 401
        raise UnauthorizedError, "There was a problem with the access token: #{response.body}"
      when 403
        raise ForbiddenError, "The operation requires privileges which the client does not have: #{response.body}"
      when 404
        raise ResourceNotFound, "Endpoint not found or resource does not exist: #{response.body}"
      when 409
        raise ConflictError, "Resource cannot be updated: #{response.body}"
      when 422
        raise ValidationError, "There was a validation problem with the request: #{response.body}"
      when 500
        raise ServiceUnavailable, "The remote server returned an internal server error: #{response.body}"
      else
        raise StandardError, "Unexpected response: #{response.status} #{response.body}"
      end
    end
  end
end
