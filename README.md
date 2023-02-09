# FolioClient

FolioClient is a Ruby gem that acts as a client to the RESTful HTTP APIs provided by the Folio ILS API.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add folio_client

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install folio_client

## Usage

```ruby
require 'folio_client'

# this will configure the client and request an access token
client = FolioClient.configure(
    url: 'https://okapi-dev.stanford.edu',
    login_params: { username: 'xxx', password: 'yyy' },
    okapi_headers: { 'X-Okapi-Tenant': 'sul', 'User-Agent': 'FolioApiClient' }
)

response = client.get('/organizations/organizations')
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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sul-dlss/folio_client.
