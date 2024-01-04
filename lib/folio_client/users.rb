# frozen_string_literal: true

class FolioClient
  # Query user records in Folio; see
  # https://s3.amazonaws.com/foliodocs/api/mod-users/r/users.html
  class Users
    attr_accessor :client

    # @param client [FolioClient] the configured client
    def initialize(client)
      @client = client
    end

    # @param query [String] an optional query to limit the number of users returned
    # @param limit [Integer] the number of results to return (defaults to 10,000)
    # @param offset [Integer] the offset for results returned (defaults to 0)
    # @param lang [String] language code for returned results (defaults to 'en')
    def fetch_list(query: nil, limit: 10_000, offset: 0, lang: 'en')
      params = { limit: limit, offset: offset, lang: lang }
      params[:query] = query if query
      client.get('/users', params)
    end

    # @param id [String] id for requested user
    # @param lang [String] language code for returned results (defaults to 'en')
    def fetch_user_details(id:, lang: 'en')
      client.get("/users/#{id}", {
                   lang: lang
                 })
    end
  end
end
