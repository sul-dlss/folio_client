# frozen_string_literal: true

require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"
require "faraday"
require "singleton"
require "ostruct"
require "zeitwerk"

# Load the gem's internal dependencies: use Zeitwerk instead of needing to manually require classes
Zeitwerk::Loader.for_gem.setup

# Client for interacting with the Folio API
class FolioClient
  include Singleton

  # Base class for all FolioClient errors
  class Error < StandardError; end

  # Error raised by the Folio Auth API returns a 401 Unauthorized
  class UnauthorizedError < Error; end

  # Error raised when the Folio API returns a 404 NotFound, or returns 0 results when one was expected
  class ResourceNotFound < Error; end

  # Error raised when e.g. exactly one result was expected, but more than one was returned
  class MultipleResourcesFound < Error; end

  # Error raised when the Folio API returns a 403 Forbidden
  class ForbiddenError < Error; end

  # Error raised when the Folio API returns a 500
  class ServiceUnavailable < Error; end

  # Error raised when the Folio API returns a 422 Unprocessable Entity
  class ValidationError < Error; end

  DEFAULT_HEADERS = {
    accept: "application/json, text/plain",
    content_type: "application/json"
  }.freeze

  class << self
    # @param url [String] the folio API URL
    # @param login_params [Hash] the folio client login params (username:, password:)
    # @param okapi_headers [Hash] the okapi specific headers to add (X-Okapi-Tenant:, User-Agent:)
    def configure(url:, login_params:, okapi_headers:)
      instance.config = OpenStruct.new(url: url, login_params: login_params, okapi_headers: okapi_headers, token: nil)

      instance.config.token = Authenticator.token(login_params, connection)

      self
    end

    delegate :config, :connection, :get, :post, to: :instance
    delegate :fetch_hrid, :fetch_marc_hash, :has_instance_status?, :data_import, :holdings, to: :instance
  end

  attr_accessor :config

  # Send an authenticated get request
  # @param path [String] the path to the Folio API request
  # @param request [Hash] params to get to the API
  def get(path, params = {})
    response = TokenWrapper.refresh(config, connection) do
      connection.get(path, params, {"x-okapi-token": config.token})
    end

    UnexpectedResponse.call(response) unless response.success?

    return nil if response.body.blank?

    JSON.parse(response.body)
  end

  # Send an authenticated post request
  # If the body is JSON, it will be automatically serialized
  # @param path [String] the path to the Folio API request
  # @param body [Object] body to post to the API as JSON
  def post(path, body = nil, content_type: "application/json")
    req_body = (content_type == "application/json") ? body&.to_json : body
    response = TokenWrapper.refresh(config, connection) do
      req_headers = {
        "x-okapi-token": config.token,
        "content-type": content_type
      }
      connection.post(path, req_body, req_headers)
    end

    UnexpectedResponse.call(response) unless response.success?

    return nil if response.body.blank?

    JSON.parse(response.body)
  end

  # the base connection to the Folio API
  def connection
    @connection ||= Faraday.new(
      url: config.url,
      headers: DEFAULT_HEADERS.merge(config.okapi_headers || {})
    )
  end

  # Public methods available on the FolioClient below
  def fetch_hrid(...)
    Inventory
      .new(self)
      .fetch_hrid(...)
  end

  def fetch_marc_hash(...)
    SourceStorage
      .new(self)
      .fetch_marc_hash(...)
  end

  def has_instance_status?(...)
    Inventory
      .new(self)
      .has_instance_status?(...)
  end

  def data_import(...)
    DataImport
      .new(self)
      .import(...)
  end

  def holdings(...)
    Holdings
      .new(self, ...)
  end
end
