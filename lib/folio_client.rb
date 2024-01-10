# frozen_string_literal: true

require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/object/blank'
require 'faraday'
require 'faraday-cookie_jar'
require 'marc'
require 'ostruct'
require 'singleton'
require 'zeitwerk'

# Load the gem's internal dependencies: use Zeitwerk instead of needing to manually require classes
Zeitwerk::Loader.for_gem.setup

# Client for interacting with the Folio API
# rubocop:disable Metrics/ClassLength
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

  # Error raised when the Folio API returns a 409 Conflict
  class ConflictError < Error; end

  DEFAULT_HEADERS = {
    accept: 'application/json, text/plain',
    content_type: 'application/json'
  }.freeze

  class << self
    # @param url [String] the folio API URL
    # @param login_params [Hash] the folio client login params (username:, password:)
    # @param okapi_headers [Hash] the okapi specific headers to add (X-Okapi-Tenant:, User-Agent:)
    # @param legacy_auth [Boolean] true to use legacy /login rather than Poppy /login-with-expiry endpoint
    # @return [FolioClient] the configured Singleton class
    def configure(url:, login_params:, okapi_headers:, timeout: default_timeout, legacy_auth: true)
      # rubocop:disable Style/OpenStructUse
      instance.config = OpenStruct.new(
        # For the initial token, use a dummy value to avoid hitting any APIs
        # during configuration, allowing `with_token_refresh_when_unauthorized` to handle
        # auto-magic token refreshing. Why not immediately get a valid token? Our apps
        # commonly invoke client `.configure` methods in the initializer in all
        # application environments, even those that are never expected to
        # connect to production APIs, such as local development machines.
        #
        # NOTE: `nil` and blank string cannot be used as dummy values here as
        # they lead to a malformed request to be sent, which triggers an
        # exception not rescued by `with_token_refresh_when_unauthorized`
        token: 'a temporary dummy token to avoid hitting the API before it is needed',
        url: url,
        login_params: login_params,
        okapi_headers: okapi_headers,
        timeout: timeout,
        legacy_auth: legacy_auth # default true until we have new token endpoint enabled in Poppy
      )
      # rubocop:enable Style/OpenStructUse

      self
    end

    delegate :config, :connection, :cookie_jar, :data_import, :default_timeout,
             :edit_marc_json, :fetch_external_id, :fetch_hrid,
             :fetch_instance_info, :fetch_marc_hash, :fetch_marc_xml,
             :force_token_refresh!, :get, :has_instance_status?,
             :http_get_headers, :http_post_and_put_headers, :interface_details,
             :job_profiles, :organization_interfaces, :organizations, :users,
             :user_details, :post, :put, to: :instance
  end

  attr_accessor :config

  # Send an authenticated get request
  # @param path [String] the path to the Folio API request
  # @param params [Hash] params to get to the API
  def get(path, params = {})
    response = with_token_refresh_when_unauthorized do
      connection.get(path, params, { 'x-okapi-token': config.token })
    end

    UnexpectedResponse.call(response) unless response.success?

    return nil if response.body.blank?

    JSON.parse(response.body)
  end

  # Send an authenticated post request
  # If the body is JSON, it will be automatically serialized
  # @param path [String] the path to the Folio API request
  # @param body [Object] body to post to the API as JSON
  # rubocop:disable Metrics/MethodLength
  def post(path, body = nil, content_type: 'application/json')
    req_body = content_type == 'application/json' ? body&.to_json : body
    response = with_token_refresh_when_unauthorized do
      req_headers = {
        'x-okapi-token': config.token,
        'content-type': content_type
      }
      connection.post(path, req_body, req_headers)
    end

    UnexpectedResponse.call(response) unless response.success?

    return nil if response.body.blank?

    JSON.parse(response.body)
  end
  # rubocop:enable Metrics/MethodLength

  # Send an authenticated put request
  # If the body is JSON, it will be automatically serialized
  # @param path [String] the path to the Folio API request
  # @param body [Object] body to put to the API as JSON
  # rubocop:disable Metrics/MethodLength
  def put(path, body = nil, content_type: 'application/json')
    req_body = content_type == 'application/json' ? body&.to_json : body
    response = with_token_refresh_when_unauthorized do
      req_headers = {
        'x-okapi-token': config.token,
        'content-type': content_type
      }
      connection.put(path, req_body, req_headers)
    end

    UnexpectedResponse.call(response) unless response.success?

    return nil if response.body.blank?

    JSON.parse(response.body)
  end
  # rubocop:enable Metrics/MethodLength

  # the base connection to the Folio API
  def connection
    @connection ||= Faraday.new(
      url: config.url,
      headers: DEFAULT_HEADERS.merge(config.okapi_headers || {}),
      request: { timeout: config.timeout }
    ) do |faraday|
      faraday.use :cookie_jar, jar: cookie_jar
      faraday.adapter Faraday.default_adapter
    end
  end

  def cookie_jar
    @cookie_jar ||= HTTP::CookieJar.new
  end

  # Public methods available on the FolioClient below

  # @see Inventory#fetch_hrid
  def fetch_hrid(...)
    Inventory
      .new
      .fetch_hrid(...)
  end

  # @see Inventory#fetch_external_id
  def fetch_external_id(...)
    Inventory
      .new
      .fetch_external_id(...)
  end

  # @see Inventory#fetch_instance_info
  def fetch_instance_info(...)
    Inventory
      .new
      .fetch_instance_info(...)
  end

  # @see SourceStorage#fetch_marc_hash
  def fetch_marc_hash(...)
    SourceStorage
      .new
      .fetch_marc_hash(...)
  end

  # @see SourceStorage#fetch_marc_xml
  def fetch_marc_xml(...)
    SourceStorage
      .new
      .fetch_marc_xml(...)
  end

  # @see Inventory#has_instance_status?
  def has_instance_status?(...) # rubocop:disable Naming/PredicateName
    Inventory
      .new
      .has_instance_status?(...)
  end

  # @ see DataImport#import
  def data_import(...)
    DataImport
      .new
      .import(...)
  end

  # @ see DataImport#job_profiles
  def job_profiles(...)
    DataImport
      .new
      .job_profiles(...)
  end

  # @see RecordsEditor#edit_marc_json
  def edit_marc_json(...)
    RecordsEditor
      .new
      .edit_marc_json(...)
  end

  # @see Organizations#fetch_list
  def organizations(...)
    Organizations
      .new
      .fetch_list(...)
  end

  # @see Organizations#fetch_interface_list
  def organization_interfaces(...)
    Organizations
      .new
      .fetch_interface_list(...)
  end

  # @see Organizations#fetch_interface_details
  def interface_details(...)
    Organizations
      .new
      .fetch_interface_details(...)
  end

  # @see Users#fetch_list
  def users(...)
    Users
      .new
      .fetch_list(...)
  end

  # @see Users#fetch_user_details
  def user_details(...)
    Users
      .new
      .fetch_user_details(...)
  end

  def default_timeout
    120
  end

  def force_token_refresh!
    config.token = Authenticator.token
  end

  private

  # Wraps API operations to request new access token if expired.
  # @yieldreturn response [Faraday::Response] the response to inspect
  #
  # @note You likely want to make sure you're wrapping a _single_ HTTP request in this
  # method, because 1) all calls in the block will be retried from the top if there's
  # an authN failure detected, and 2) only the response returned by the block will be
  # inspected for authN failure.
  # Related: consider that the client instance and its token will live across many
  # invocations of the FolioClient methods once the client is configured by a consuming application,
  # since this class is a Singleton.  Thus, a token may expire between any two calls (i.e. it
  # isn't necessary for a set of operations to collectively take longer than the token lifetime for
  # expiry to fall in the middle of that related set of HTTP calls).
  def with_token_refresh_when_unauthorized
    response = yield

    # if unauthorized, token has likely expired. try to get a new token and then retry the same request(s).
    if response.status == 401 || response.status == 403
      force_token_refresh!
      response = yield
    end

    response
  end
end
# rubocop:enable Metrics/ClassLength
