[![Gem Version](https://badge.fury.io/rb/folio_client.svg)](https://badge.fury.io/rb/folio_client)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/sul-dlss/folio_client/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/sul-dlss/folio_client/tree/main)
[![Code Climate](https://api.codeclimate.com/v1/badges/34dd73ba47058709c666/maintainability)](https://codeclimate.com/github/sul-dlss/folio_client/maintainability)
[![Code Climate Test Coverage](https://api.codeclimate.com/v1/badges/34dd73ba47058709c666/test_coverage)](https://codeclimate.com/github/sul-dlss/folio_client/test_coverage)

# FolioClient

FolioClient is a Ruby gem that acts as a client to the RESTful HTTP APIs provided by the Folio ILS API.  It requires ruby 3.0 or better.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add folio_client

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install folio_client

## Usage

The gem should be configured first, and then you can either call API endpoints directly using GET or POST, or more commonly, use the helper methods provided, as described in the section below.

```ruby
require 'folio_client'

# this will configure the client and request an access token
client = FolioClient.configure(
    url: 'https://okapi-dev.stanford.edu',
    login_params: { username: 'xxx', password: 'yyy' },
    okapi_headers: { 'X-Okapi-Tenant': 'sul', 'User-Agent': 'FolioApiClient' }
)

response = client.get('/organizations/organizations', {query_string_param: 'abcdef'})

response = client.post('/some/post/endpoint', params_hash.to_json)
```

Note that the settings will live in the consumer of this gem and would typically be used like this:

```ruby
require 'folio_client'

client = FolioClient.configure(
    url: Settings.okapi.url,
    login_params: Settings.okapi.login_params,
    okapi_headers: Settings.okapi.headers
)
```

The client is smart enough to automatically request a new token if it detects the one it is using has expired.  If for some reason, you want to immediately request a new token, you can do this:

```ruby
client.config.token = FolioClient::Authenticator.token(client.config.login_params, client.connection)
```

## API Coverage

FolioClient provides a number of methods to simplify connecting to the RESTful HTTP API of the Folio API. In this section we list all of the available methods, reflecting how much of the API the client covers.  Note that this assumes the client has already been configured, as described above.  See dor-services-app for an example of configuration and usage.

```ruby
# Lookup an instance hrid given a barcode
# returns a string if found, nil if nothing found
client.fetch_hrid(barcode: "12345")
 => "a7927874"

# Request a MARC record given an instance hrid
# returns a hash if found; raises FolioClient::UnexpectedResponse::ResourceNotFound if instance_hrid not found
client.fetch_marc_hash(instance_hrid: "a7927874")
 => {"fields"=>
  [{"003"=>"FOLIO"}....]
  }

# Import a MARC record
data_importer = client.data_import(marc: my_marc, job_profile_id: '4ba4f4ab', job_profile_name: 'ETDs')
# If called too quickly, might get Failure(:not_found)
data_importer.status
 => Failure(:pending)
data_importer.wait_until_complete
 => Success()
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sul-dlss/folio_client.
