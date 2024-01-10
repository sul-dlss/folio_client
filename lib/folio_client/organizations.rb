# frozen_string_literal: true

class FolioClient
  # Query organization records in Folio; see
  # https://s3.amazonaws.com/foliodocs/api/mod-organizations/p/organizations.html
  # https://s3.amazonaws.com/foliodocs/api/mod-organizations-storage/p/interface.html
  class Organizations
    # @param query [String] an optional query to limit the number of organizations returned
    # @param limit [Integer] the number of results to return (defaults to 10,000)
    # @param offset [Integer] the offset for results returned (defaults to 0)
    # @param lang [String] language code for returned results (defaults to 'en')
    def fetch_list(query: nil, limit: 10_000, offset: 0, lang: 'en')
      params = { limit: limit, offset: offset, lang: lang }
      params[:query] = query if query
      client.get('/organizations/organizations', params)
    end

    # @param query [String] an optional query to limit the number of organization interfaces returned
    # @param limit [Integer] the number of results to return (defaults to 10,000)
    # @param offset [Integer] the offset for results returned (defaults to 0)
    # @param lang [String] language code for returned results (defaults to 'en')
    def fetch_interface_list(query: nil, limit: 10_000, offset: 0, lang: 'en')
      params = { limit: limit, offset: offset, lang: lang }
      params[:query] = query if query
      client.get('/organizations-storage/interfaces', params)
    end

    # @param id [String] id for requested storage interface
    # @param lang [String] language code for returned result (defaults to 'en')
    def fetch_interface_details(id:, lang: 'en')
      client.get("/organizations-storage/interfaces/#{id}", {
                   lang: lang
                 })
    end

    private

    def client
      FolioClient.instance
    end
  end
end
