# frozen_string_literal: true

require 'http/cookie' # Workaround for https://github.com/sparklemotion/http-cookie/issues/62
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/object/blank'
require 'deprecation'
require 'faraday'
require 'faraday-cookie_jar'
require 'marc'
require 'ostruct'
require 'singleton'
require 'zeitwerk'

# Autoload gem internals.
Zeitwerk::Loader.for_gem.setup

# Client for interacting with the Folio API.
class FolioClient # rubocop:disable Metrics/ClassLength
  include Singleton

  # Base class for all FolioClient errors.
  class Error < StandardError; end

  # Raised when the Folio Auth API returns 401 Unauthorized.
  class UnauthorizedError < Error; end

  # Raised when the Folio API returns 404 Not Found, or when 0 results are
  # returned where one was expected.
  class ResourceNotFound < Error; end

  # Raised when exactly one resource was expected but multiple were returned.
  class MultipleResourcesFound < Error; end

  # Raised when the Folio API returns 403 Forbidden.
  class ForbiddenError < Error; end

  # Raised when the Folio API returns 500-level availability errors.
  class ServiceUnavailable < Error; end

  # Raised when the Folio API returns 422 Unprocessable Entity.
  class ValidationError < Error; end

  # Raised when the Folio API returns 409 Conflict.
  class ConflictError < Error; end

  # Raised when the Folio API returns 400 Bad Request.
  class BadRequestError < Error; end

  class << self
    extend Deprecation

    Config = Struct.new('Config', :url, :login_params, :timeout, :tenant_id, :user_agent) do
      # Build default headers for Folio-bound requests.
      # @return [Hash<Symbol,String>] default request headers
      def headers
        {
          accept: 'application/json, text/plain',
          content_type: 'application/json',
          user_agent: user_agent,
          'X-Okapi-Tenant': tenant_id
        }
      end
    end

    # Configure the singleton FolioClient instance.
    # @example
    #   FolioClient.configure(
    #     url: 'https://folio.example.edu',
    #     login_params: { username: 'svc-user', password: 'secret' },
    #     tenant_id: 'sul'
    #   )
    # @param url [String] Folio API base URL
    # @param login_params [Hash] authentication payload (e.g., +username+, +password+)
    # @param tenant_id [String, nil] Folio tenant identifier
    # @param user_agent [String, nil] user agent string included on outbound requests
    # @param timeout [Integer] request timeout, in seconds
    # @return [Class<FolioClient>] the configured singleton class for chaining
    def configure(url:, login_params:, tenant_id: nil, user_agent: nil, timeout: nil)
      instance.config = Config.new(
        url: url,
        login_params: login_params,
        tenant_id: tenant_id,
        timeout: timeout || default_timeout,
        user_agent: user_agent || default_user_agent
      )

      self
    end

    # The client is intended to be used as a singleton via {.configure}, but the
    # instance methods are also available on the class itself for convenience.
    # Instead of maintaining a giant list of delegations to the singleton
    # instance, we can just delegate everything. This makes the client easier to
    # extend with additional instance methods without needing to update the
    # delegation list.
    delegate_missing_to :instance
  end

  # @return [FolioClient::Config, nil] active runtime configuration
  attr_accessor :config

  # Send an authenticated GET request.
  # @param path [String] API path relative to configured +url+
  # @param params [Hash] query parameters
  # @return [Hash, Array, nil] parsed JSON body, or +nil+ for empty body
  # @yield [Faraday::Response] optional block to receive the raw +Faraday::Response+ object
  # @raise [FolioClient::Error] when Folio responds with an unexpected status
  def get(path, params = {})
    response = with_token_refresh_when_unauthorized do
      connection.get(path, params)
    end

    UnexpectedResponse.call(response) unless response.success?

    yield response if block_given?

    JSON.parse(response.body) if response.body.present?
  end

  # Send an authenticated POST request.
  # If +content_type+ is +application/json+, +body+ is serialized with +to_json+.
  # Otherwise +body+ is sent unchanged.
  # @param path [String] API path relative to configured +url+
  # @param body [Hash, String, nil] request payload
  # @param content_type [String] MIME type of request body
  # @return [Hash, Array, nil] parsed JSON body, or +nil+ for empty body
  # @yield [Faraday::Response] optional block to receive the raw +Faraday::Response+ object
  # @raise [FolioClient::Error] when Folio responds with an unexpected status
  def post(path, body = nil, content_type: 'application/json')
    req_body = content_type == 'application/json' ? body&.to_json : body
    response = with_token_refresh_when_unauthorized do
      connection.post(path, req_body, { content_type: content_type })
    end

    UnexpectedResponse.call(response) unless response.success?

    yield response if block_given?

    JSON.parse(response.body) if response.body.present?
  end

  # Send an authenticated PUT request.
  # If +content_type+ is +application/json+, +body+ is serialized with +to_json+.
  # Otherwise +body+ is sent unchanged.
  # @param path [String] API path relative to configured +url+
  # @param body [Hash, String, nil] request payload
  # @param content_type [String] MIME type of request body
  # @param exception_args [Hash] supplemental context forwarded to +UnexpectedResponse+
  # @return [Hash, Array, nil] parsed JSON body, or +nil+ for empty body
  # @yield [Faraday::Response] optional block to receive the raw +Faraday::Response+ object
  # @raise [FolioClient::Error] when Folio responds with an unexpected status
  def put(path, body = nil, content_type: 'application/json', **exception_args)
    req_body = content_type == 'application/json' ? body&.to_json : body
    response = with_token_refresh_when_unauthorized do
      connection.put(path, req_body, { content_type: content_type })
    end

    UnexpectedResponse.call(response, **exception_args) unless response.success?

    yield response if block_given?

    JSON.parse(response.body) if response.body.present?
  end

  # Send an authenticated DELETE request
  # @note None of the current FolioClient services use this method, but it's provided
  #   primarily to accommodate work in folio-tasks
  # @param path [String] API path relative to configured +url+
  # @return [Hash, Array, nil] parsed JSON body, or +nil+ for empty body
  # @yield [Faraday::Response] optional block to receive the raw +Faraday::Response+ object
  # @raise [FolioClient::Error] when Folio responds with an unexpected status
  def delete(path)
    response = with_token_refresh_when_unauthorized do
      connection.delete(path)
    end

    UnexpectedResponse.call(response) unless response.success?

    yield response if block_given?

    JSON.parse(response.body) if response.body.present?
  end

  # Build (or memoize) the base Faraday connection.
  # @return [Faraday::Connection] configured HTTP connection
  def connection
    @connection ||= Faraday.new(
      url: config.url,
      headers: config.headers,
      request: { timeout: config.timeout }
    ) do |faraday|
      faraday.use :cookie_jar, jar: cookie_jar
      faraday.adapter Faraday.default_adapter
    end
  end

  # Build (or memoize) the cookie jar used by Faraday to store authentication cookies.
  # @return [HTTP::CookieJar] cookie storage for session-aware requests
  def cookie_jar
    @cookie_jar ||= HTTP::CookieJar.new
  end

  # Fetch a Folio HRID by instance identifier or query context.
  # @see Inventory#fetch_hrid
  # @return [Object] delegated return value from +Inventory#fetch_hrid+
  def fetch_hrid(...)
    inventory.fetch_hrid(...)
  end

  # Fetch the Folio external id for a matching record.
  # @see Inventory#fetch_external_id
  # @return [Object] delegated return value from +Inventory#fetch_external_id+
  def fetch_external_id(...)
    inventory.fetch_external_id(...)
  end

  # Fetch inventory instance details.
  # @see Inventory#fetch_instance_info
  # @return [Object] delegated return value from +Inventory#fetch_instance_info+
  def fetch_instance_info(...)
    inventory.fetch_instance_info(...)
  end

  # Fetch location details from inventory.
  # @see Inventory#fetch_location
  # @return [Object] delegated return value from +Inventory#fetch_location+
  def fetch_location(...)
    inventory.fetch_location(...)
  end

  # Fetch holdings associated with a record.
  # @see Inventory#fetch_holdings
  # @return [Object] delegated return value from +Inventory#fetch_holdings+
  def fetch_holdings(...)
    inventory.fetch_holdings(...)
  end

  # Update an existing holdings record.
  # @see Inventory#update_holdings
  # @return [Object] delegated return value from +Inventory#update_holdings+
  def update_holdings(...)
    inventory.update_holdings(...)
  end

  # Create a new holdings record.
  # @see Inventory#create_holdings
  # @return [Object] delegated return value from +Inventory#create_holdings+
  def create_holdings(...)
    inventory.create_holdings(...)
  end

  # Fetch MARC data as a Ruby hash.
  # @see SourceStorage#fetch_marc_hash
  # @return [Object] delegated return value from +SourceStorage#fetch_marc_hash+
  def fetch_marc_hash(...)
    source_storage.fetch_marc_hash(...)
  end

  # Fetch MARC data as XML.
  # @see SourceStorage#fetch_marc_xml
  # @return [Object] delegated return value from +SourceStorage#fetch_marc_xml+
  def fetch_marc_xml(...)
    source_storage.fetch_marc_xml(...)
  end

  # Determine whether an instance has the requested status.
  # @see Inventory#has_instance_status?
  # @return [Boolean] delegated predicate result
  def has_instance_status?(...) # rubocop:disable Naming/PredicatePrefix
    inventory.has_instance_status?(...)
  end

  # Run an inventory data import workflow.
  # @see DataImport#import
  # @return [Object] delegated return value from +DataImport#import+
  def data_import(...)
    data_import_service.import(...)
  end

  # List available data-import job profiles.
  # @see DataImport#job_profiles
  # @return [Object] delegated return value from +DataImport#job_profiles+
  def job_profiles(...)
    data_import_service.job_profiles(...)
  end

  # Edit MARC-in-JSON records.
  # @see RecordsEditor#edit_marc_json
  # @return [Object] delegated return value from +RecordsEditor#edit_marc_json+
  def edit_marc_json(...)
    records_editor.edit_marc_json(...)
  end

  # List organizations.
  # @see Organizations#fetch_list
  # @return [Object] delegated return value from +Organizations#fetch_list+
  def organizations(...)
    organizations_service.fetch_list(...)
  end

  # List interfaces for organizations.
  # @see Organizations#fetch_interface_list
  # @return [Object] delegated return value from +Organizations#fetch_interface_list+
  def organization_interfaces(...)
    organizations_service.fetch_interface_list(...)
  end

  # Fetch detailed interface information for an organization interface.
  # @see Organizations#fetch_interface_details
  # @return [Object] delegated return value from +Organizations#fetch_interface_details+
  def interface_details(...)
    organizations_service.fetch_interface_details(...)
  end

  # List users.
  # @see Users#fetch_list
  # @return [Object] delegated return value from +Users#fetch_list+
  def users(...)
    users_service.fetch_list(...)
  end

  # Fetch details for a user.
  # @see Users#fetch_user_details
  # @return [Object] delegated return value from +Users#fetch_user_details+
  def user_details(...)
    users_service.fetch_user_details(...)
  end

  # Force a refresh of the current auth token.
  #
  # @return [Object] return value from +Authenticator.refresh_token!+
  def force_token_refresh!
    Authenticator.refresh_token!
  end

  # Default HTTP timeout in seconds.
  #
  # @return [Integer]
  def default_timeout
    180
  end

  # Default user-agent string used for outbound requests.
  #
  # @return [String]
  def default_user_agent
    "folio_client #{VERSION}"
  end

  private

  STATUSES_REQUIRING_TOKEN_REFRESH = [401, 403].freeze
  private_constant :STATUSES_REQUIRING_TOKEN_REFRESH

  # Wrap API operations to refresh and retry when auth has expired.
  # @yieldreturn [Faraday::Response] response from a single HTTP request
  # @return [Faraday::Response] original or retried response
  # @note Wrap one HTTP call per block. If auth fails, the entire block is retried.
  #   Only the final response yielded by the block is inspected for auth failure.
  # @note Because this class is a Singleton, its token can outlive many client calls.
  #   Expiration can occur between any two invocations, even when those calls are
  #   logically related from the caller's perspective.
  def with_token_refresh_when_unauthorized
    response = yield

    return response unless STATUSES_REQUIRING_TOKEN_REFRESH.include?(response.status)

    force_token_refresh!

    yield
  end

  # Build an inventory service object.
  # @return [Inventory]
  def inventory
    Inventory.new
  end

  # Build a source-storage service object.
  # @return [SourceStorage]
  def source_storage
    SourceStorage.new
  end

  # Build a data-import service object.
  # @return [DataImport]
  def data_import_service
    DataImport.new
  end

  # Build a records-editor service object.
  # @return [RecordsEditor]
  def records_editor
    RecordsEditor.new
  end

  # Build an organizations service object.
  # @return [Organizations]
  def organizations_service
    Organizations.new
  end

  # Build a users service object.
  # @return [Users]
  def users_service
    Users.new
  end
end
