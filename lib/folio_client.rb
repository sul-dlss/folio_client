# frozen_string_literal: true

require "active_support/core_ext/module/delegation"
require "faraday"
require "singleton"
require "ostruct"
require "zeitwerk"

# Load the gem's internal dependencies: use Zeitwerk instead of needing to manually require classes
Zeitwerk::Loader.for_gem.setup

# Client for interacting with the Folio API
class FolioClient
  include Singleton

  DEFAULT_HEADERS = {
    accept: "application/json, text/plain",
    content_type: "application/json"
  }.freeze

  class << self
    # @param url [String] the folio API URL
    # @param login_params [Hash] the folio client login params (username:, password:)
    # @param okapi_headers [Hash] the okapi specific headers to add (X-Okapi-Tenant:, User-Agent:)
    def configure(url:, login_params:, okapi_headers:)
      instance.config = OpenStruct.new(url:, login_params:, okapi_headers:, token: nil)

      instance.config.token = Authenticator.token(login_params, connection)

      self
    end

    delegate :config, :connection, :get, :post, to: :instance
  end

  attr_accessor :config

  # Send an authenticated get request
  # @param path [String] the path to the Folio API request
  # @param request [Hash] params to get to the API
  def get(path, params = {})
    response = connection.get(path, params, { "x-okapi-token": config.token })

    UnexpectedResponse.call(response) unless response.success?

    JSON.parse(response.body)
  end

  # Send an authenticated post request
  # @param path [String] the path to the Folio API request
  # @param request [json] request body to post to the API
  def post(path, request = nil)
    response = connection.post(path, request, { "x-okapi-token": config.token })

    UnexpectedResponse.call(response) unless response.success?

    JSON.parse(response.body)
  end

  # the base connection to the Folio API
  def connection
    @connection ||= Faraday.new(
      url: config.url,
      headers: DEFAULT_HEADERS.merge(config.okapi_headers || {})
    )
  end
end
