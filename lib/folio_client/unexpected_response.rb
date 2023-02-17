# frozen_string_literal: true

class FolioClient
  # Handles unexpected responses when communicating with Folio
  class UnexpectedResponse
    # Error raised by the Folio Auth API returns a 422 Unauthorized
    class UnauthorizedError < StandardError; end

    # Error raised when the Folio API returns a 404 NotFound, or returns 0 results when one was expected
    class ResourceNotFound < StandardError; end

    # Error raised when e.g. exactly one result was expected, but more than one was returned
    class MultipleResourcesFound < StandardError; end

    # Error raised when the Folio API returns a 403 Forbidden
    class ForbiddenError < StandardError; end

    # Error raised when the Folio API returns a 500
    class ServiceUnavailable < StandardError; end

    # @param [Faraday::Response] response
    def self.call(response)
      case response.status
      when 401
        raise UnauthorizedError, "There was a problem with the access token: #{response.body}"
      when 403
        raise ForbiddenError, "The operation requires privileges which the client does not have: #{response.body}"
      when 404
        raise ResourceNotFound, "Endpoint not found or resource does not exist: #{response.body}"
      when 422
        raise UnauthorizedError, "There was a problem fetching the access token: #{response.body} "
      when 500
        raise ServiceUnavailable, "The remote server returned an internal server error."
      else
        raise StandardError, "Unexpected response: #{response.status} #{response.body}"
      end
    end
  end
end
