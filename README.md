[![Gem Version](https://badge.fury.io/rb/folio_client.svg)](https://badge.fury.io/rb/folio_client)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/sul-dlss/folio_client/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/sul-dlss/folio_client/tree/main)
[![codecov](https://codecov.io/github/sul-dlss/folio_client/graph/badge.svg?token=8HS0JOVVF9)](https://codecov.io/github/sul-dlss/folio_client)

# FolioClient

FolioClient is a Ruby gem that acts as a client to the RESTful HTTP APIs provided by the Folio ILS API. It requires ruby 3.0 or better.

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
    okapi_headers: Settings.okapi.headers,
)
```

The client is smart enough to automatically request a new token if it detects the one it is using has expired. If for some reason, you want to immediately request a new token, you can do this:

```ruby
client.force_token_refresh! # or `FolioClient.force_token_refresh!` as they are identical
```

## API Coverage

FolioClient provides a number of methods to simplify connecting to the RESTful HTTP API of the Folio API. In this section we list all of the available methods, reflecting how much of the API the client covers. Note that this assumes the client has already been configured, as described above. See dor-services-app for an example of configuration and usage.

```ruby
# Lookup an instance hrid given a barcode
# returns a string if found, nil if nothing found
client.fetch_hrid(barcode: "12345")
 => "a7927874"

# Request a MARC record given an instance hrid
# returns a hash if found; raises FolioClient::ResourceNotFound if instance_hrid not found
client.fetch_marc_hash(instance_hrid: "a7927874")
 => {"fields"=>
  [{"003"=>"FOLIO"}....]
  }

# Import MARC records into FOLIO
data_importer = client.data_import(records: [marc_record1, marc_record2], job_profile_id: '4ba4f4ab', job_profile_name: 'ETDs')
# If called too quickly, might get Failure(:not_found)
data_importer.status
 => Failure(:pending)
data_importer.wait_until_complete
 => Success()
data_importer.instance_hrids
 => Success(["in00000000010", "in00000000011"])

# Get list of organizations (filtered with an optional query)
# see https://s3.amazonaws.com/foliodocs/api/mod-organizations/p/organizations.html#organizations_organizations_get
 client.organizations
 => {"organizations"=>[
     {"id"=>"4b1a42f9-b310-492c-a71d-b8edcd30ac0c",
    "name"=>"Seventh Art Releasing",
    "code"=>"7ART-SUL",
    "exportToAccounting"=>true,
    "status"=>"Active",
    "organizationTypes"=>[],
    "aliases"=>[],
    "addresses"=>],.....
    "totalRecords"=>100}

client.organizations(query: 'name="Seventh"')
=> {"organizations"=>[....

# Get list of organization interface items (filtered with an optional query)
# see https://s3.amazonaws.com/foliodocs/api/mod-organizations-storage/p/interface.html#organizations_storage_interfaces_get
client.organization_interfaces
 => {"interfaces"=>
        [{"id"=>"c6f7470e-6229-45ce-b3f9-32006e9affcf",
          "name"=>"tes",
          "type"=>["Invoices"],
    .....],....
    "totalRecords"=>100}

 client.organization_interfaces(query: 'name="tes"')
  => {"interfaces"=>....

# Get details for a specific organization interface
# see https://s3.amazonaws.com/foliodocs/api/mod-organizations-storage/p/interface.html#organizations_storage_interfaces__id__get
client.interface_details(id: 'c6f7470e-6229-45ce-b3f9-32006e9affcf')
 =>
    {"id"=>"c6f7470e-6229-45ce-b3f9-32006e9affcf",
    "name"=>"tes",
    "type"=>["Invoices"],
    "metadata"=>
    {"createdDate"=>"2023-02-16T22:27:51.515+00:00",
    "createdByUserId"=>"38524916-598d-4edf-a2ef-04bba7e78ad6",
    "updatedDate"=>"2023-02-16T22:27:51.515+00:00",
    "updatedByUserId"=>"38524916-598d-4edf-a2ef-04bba7e78ad6"}}

# Get list of users (filtered with an optional query)
# see https://s3.amazonaws.com/foliodocs/api/mod-users/r/users.html#users_get
client.users(query: 'username=="test*"')
=> {"users"=>
  [{"username"=>"testing",
    "id"=>"bbbadd51-c2f1-4107-a54d-52b39087725c",
    "externalSystemId"=>"00324439",
    "barcode"=>"2559202566",
    "active"=>false,
    "departments"=>[],
    "proxyFor"=>[],
    "personal"=>
     {"lastName"=>"Testing",
      "firstName"=>"Test",
      "email"=>"foliotesting@lists.stanford.edu",
      "addresses"=>
       [{"countryId"=>"US",
         "addressLine1"=>"13 Fake St",
         "city"=>"Palo Alto",
         "region"=>"California",
         "postalCode"=>"94301",
         "addressTypeId"=>"93d3d88d-499b-45d0-9bc7-ac73c3a19880",
         "primaryAddress"=>true}]},
    "createdDate"=>"2023-10-01T08:50:37.203+00:00",
    "updatedDate"=>"2023-10-01T08:50:37.203+00:00",
    "metadata"=>
     {"createdDate"=>"2023-09-02T02:51:43.448+00:00",
      "createdByUserId"=>"58d0aaf6-dcda-4d5e-92da-012e6b7dd766",
      "updatedDate"=>"2023-10-01T08:50:37.196+00:00",
      "updatedByUserId"=>"58d0aaf6-dcda-4d5e-92da-012e6b7dd766"},
    "customFields"=>{"affiliation"=>"affiliate:sponsored"}}],
 "totalRecords"=>1,
 "resultInfo"=>{"totalRecords"=>1, "facets"=>[], "diagnostics"=>[]}}

# Get specific user info
# see https://s3.amazonaws.com/foliodocs/api/mod-users/r/users.html#users_get
client.user_details(id: 'bbbadd51-c2f1-4107-a54d-52b39087725c')
=> {"username"=>"testing",
    "id"=>"bbbadd51-c2f1-4107-a54d-52b39087725c",
    "externalSystemId"=>"00324439", ... # same response as above, but for single user
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Integration Testing

To test that the gem works against the Folio APIs, run `api_test.rb` via:

```shell
# NOTE: This is bash syntax, YMMV
$ export OKAPI_PASSWORD=$(vault kv get --field=content puppet/application/folio/stage/app_sdr_password)
$ export OKAPI_TENANT=sul
$ export OKAPI_USER=app_sdr
$ export OKAPI_URL=https://okapi-stage.stanford.edu
# NOTE: The args below are a list of MARC files
$ bundle exec ruby ./api_test.rb /path/to/marc/files/test.mrc /another/marc/file/at/foobar.marc
```

Inspect the output and make sure there are no errors.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sul-dlss/folio_client.
