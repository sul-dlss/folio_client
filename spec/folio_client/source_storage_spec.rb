# frozen_string_literal: true

RSpec.describe FolioClient::SourceStorage do
  subject(:source_storage) { described_class.new(client) }

  let(:args) { {url:, login_params:, okapi_headers:} }
  let(:url) { "https://folio.example.org" }
  let(:login_params) { {username: "username", password: "password"} }
  let(:okapi_headers) { {some_bogus_headers: "here"} }
  let(:token) { "aLongSTring.eNCodinga.JwTeeeee" }
  let(:client) { FolioClient.configure(**args) }
  let(:instance_hrid) { "a666" }

  let(:post_authn_request_headers) {
    {
      "Accept" => "application/json, text/plain",
      "Content-Type" => "application/json",
      "Some-Bogus-Headers" => "here",
      "X-Okapi-Token" => token
    }
  }

  before do
    stub_request(:post, "#{url}/authn/login")
      .to_return(status: 200, body: "{\"okapiToken\" : \"#{token}\"}")
    stub_request(:get, "#{url}/source-storage/source-records?instanceHrid=#{instance_hrid}")
      .with(headers: post_authn_request_headers)
      .to_return(status: 200, body: source_storage_response.to_json)
  end

  context "when exactly 1 instance record is found" do
    let(:source_storage_response) {
      {"sourceRecords" =>
        [{"recordId" => "992460aa-bfe6-50ff-93f6-65c6aa786a43",
          "snapshotId" => "5ae00995-bcb3-4fdc-8519-75c1357c44c4",
          "recordType" => "MARC_BIB",
          "parsedRecord" =>
           {"id" => "992460aa-bfe6-50ff-93f6-65c6aa786a43",
            "content" =>
             {"fields" =>
               [{"001" => "a666"},
                 {"003" => "SIRSI"},
                 {"005" => "19900820141050.0"},
                 {"008" => "750409s1961||||enk           ||| | eng  "},
                 {"010" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"a" => "   62039356\\\\72b2"}]}},
                 {"040" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"d" => "OrLoB"}]}},
                 {"050" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"a" => "M231.B66 Bb maj. 1961"}]}},
                 {"100" =>
                   {"ind1" => "1", "ind2" => " ", "subfields" => [{"a" => "Boccherini, Luigi,"}, {"d" => "1743-1805."}]}},
                 {"240" =>
                   {"ind1" => "1",
                    "ind2" => "0",
                    "subfields" => [{"a" => "Sonatas,"}, {"m" => "cello, continuo,"}, {"r" => "B♭ major"}]}},
                 {"245" =>
                   {"ind1" => " ",
                    "ind2" => "0",
                    "subfields" =>
                     [{"a" => "Sonata no. 7, in B flat, for violoncello and piano."},
                       {"c" =>
                         "Edited with realization of the basso continuo by Fritz Spiegl and Walter Bergamnn. Violoncello part edited by Joan Dickson."}]}},
                 {"260" =>
                   {"ind1" => " ",
                    "ind2" => " ",
                    "subfields" =>
                     [{"a" => "London, Schott; New York, Associated Music Publishers"}, {"c" => "[c1961]"}]}},
                 {"300" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"a" => "score (20 p.) & part."}, {"c" => "29cm."}]}},
                 {"490" => {"ind1" => "1", "ind2" => " ", "subfields" => [{"a" => "Edition [Schott]  10731"}]}},
                 {"500" =>
                   {"ind1" => " ",
                    "ind2" => " ",
                    "subfields" =>
                     [{"a" =>
                        "Edited from a recently discovered ms. Closely parallels Gruetzmacher's free arrangement of the Violoncello concerto, G. 482."}]}},
                 {"596" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"a" => "31"}]}},
                 {"650" => {"ind1" => " ", "ind2" => "0", "subfields" => [{"a" => "Sonatas (Cello and harpsichord)"}]}},
                 {"700" =>
                   {"ind1" => "1",
                    "ind2" => "2",
                    "subfields" =>
                     [{"a" => "Boccherini, Luigi,"},
                       {"d" => "1743-1805."},
                       {"t" => "Concertos,"},
                       {"m" => "cello, orchestra,"},
                       {"n" => "G. 482,"},
                       {"r" => "B♭ major"},
                       {"o" => "arranged."}]}},
                 {"830" => {"ind1" => " ", "ind2" => "0", "subfields" => [{"a" => "Edition Schott"}, {"v" => "10731"}]}},
                 {"998" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"a" => "SCORE"}]}},
                 {"035" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"a" => "(OCoLC-M)17708345"}]}},
                 {"035" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"a" => "(OCoLC-I)268876650"}]}},
                 {"918" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"a" => "666"}]}},
                 {"035" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"a" => "AAA0675"}]}},
                 {"999" =>
                   {"ind1" => "f",
                    "ind2" => "f",
                    "subfields" =>
                     [{"i" => "696ef04d-1902-5a70-aebf-98d287bce1a1"},
                       {"s" => "992460aa-bfe6-50ff-93f6-65c6aa786a43"}]}}],
              "leader" => "01185ccm a2200301   4500"}},
          "deleted" => false,
          "externalIdsHolder" => {"instanceId" => "696ef04d-1902-5a70-aebf-98d287bce1a1", "instanceHrid" => "a666"},
          "additionalInfo" => {"suppressDiscovery" => false},
          "metadata" =>
           {"createdDate" => "2023-02-11T03:54:43.938+00:00",
            "createdByUserId" => "3e2ed889-52f2-45ce-8a30-8767266f07d2",
            "updatedDate" => "2023-02-11T03:54:44.574+00:00",
            "updatedByUserId" => "3e2ed889-52f2-45ce-8a30-8767266f07d2"}}],
       "totalRecords" => 1}
    }

    it "returns the parsed JSON as a hash for the one record that was found" do
      result = source_storage.fetch_marc_hash(instance_hrid:)
      expect(result["fields"].select { |field_hash| field_hash.key?("001") }.map(&:values)).to eq([["a666"]])
      expect(result["fields"].select { |field_hash| field_hash.key?("008") }.map(&:values)).to eq([["750409s1961||||enk           ||| | eng  "]])
      expect(result["fields"].select { |field_hash| field_hash.key?("050") }.map(&:values)).to eq([[{"ind1" => " ", "ind2" => " ", "subfields" => [{"a" => "M231.B66 Bb maj. 1961"}]}]])
    end
  end

  context "when no instance records are found" do
    let(:source_storage_response) {
      {"sourceRecords" => [], "totalRecords" => 0}
    }

    it "raises a NotFound exception" do
      expect { source_storage.fetch_marc_hash(instance_hrid:) }.to raise_error(FolioClient::ResourceNotFound, "No records found for #{instance_hrid}")
    end
  end

  context "when multiple instance records are found" do
    # based on a real Folio response, but omits some returned fields, and duplicates and lightly
    # modifies the one record from the real response. that makes this spec file slightly less gigantic,
    # and still simulates the relevant part of the response structure.
    let(:source_storage_response) {
      {"sourceRecords" =>
        [
          {
            "recordId" => "992460aa-bfe6-50ff-93f6-65c6aa786a43",
            "snapshotId" => "5ae00995-bcb3-4fdc-8519-75c1357c44c4",
            "recordType" => "MARC_BIB",
            "parsedRecord" =>
             {"id" => "992460aa-bfe6-50ff-93f6-65c6aa786a43",
              "content" =>
               {"fields" =>
                 [{"001" => "a666"},
                   {"003" => "SIRSI"},
                   {"005" => "19900820141050.0"},
                   {"008" => "750409s1961||||enk           ||| | eng  "},
                   {"010" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"a" => "   62039356\\\\72b2"}]}},
                   {"040" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"d" => "OrLoB"}]}},
                   {"050" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"a" => "M231.B66 Bb maj. 1961"}]}},
                   {"100" =>
                     {"ind1" => "1", "ind2" => " ", "subfields" => [{"a" => "Boccherini, Luigi,"}, {"d" => "1743-1805."}]}},
                   {"240" =>
                     {"ind1" => "1",
                      "ind2" => "0",
                      "subfields" => [{"a" => "Sonatas,"}, {"m" => "cello, continuo,"}, {"r" => "B♭ major"}]}}],
                "leader" => "01185ccm a2200301   4500"}},
            "deleted" => false,
            "externalIdsHolder" => {"instanceId" => "696ef04d-1902-5a70-aebf-98d287bce1a1", "instanceHrid" => "a666"},
            "additionalInfo" => {"suppressDiscovery" => false},
            "metadata" =>
             {"createdDate" => "2023-02-11T03:54:43.938+00:00",
              "createdByUserId" => "3e2ed889-52f2-45ce-8a30-8767266f07d2",
              "updatedDate" => "2023-02-11T03:54:44.574+00:00",
              "updatedByUserId" => "3e2ed889-52f2-45ce-8a30-8767266f07d2"}
          },
          {
            "recordId" => "992460aa-bfe6-50ff-93f6-65c6aa786a54",
            "snapshotId" => "5ae00995-bcb3-4fdc-8519-75c1357c44d5",
            "recordType" => "MARC_BIB",
            "parsedRecord" =>
             {"id" => "992460aa-bfe6-50ff-93f6-65c6aa786a54",
              "content" =>
               {"fields" =>
                 [{"001" => "a666"},
                   {"003" => "SIRSI"},
                   {"005" => "19900820141050.0"},
                   {"008" => "750409s1961||||enk           ||| | eng  "},
                   {"010" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"a" => "   62039356\\\\72b2"}]}},
                   {"040" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"d" => "OrLoB"}]}},
                   {"050" => {"ind1" => " ", "ind2" => " ", "subfields" => [{"a" => "M231.B66 Bb maj. 1961"}]}},
                   {"100" =>
                     {"ind1" => "1", "ind2" => " ", "subfields" => [{"a" => "Boccherini, Luigi,"}, {"d" => "1743-1805."}]}},
                   {"240" =>
                     {"ind1" => "1",
                      "ind2" => "0",
                      "subfields" => [{"a" => "Sonatas,"}, {"m" => "cello, continuo,"}, {"r" => "B♭ major"}]}}],
                "leader" => "01185ccm a2200301   4500"}},
            "deleted" => false,
            "externalIdsHolder" => {"instanceId" => "696ef04d-1902-5a70-aebf-98d287bce1b2", "instanceHrid" => "a666"},
            "additionalInfo" => {"suppressDiscovery" => false},
            "metadata" =>
             {"createdDate" => "2023-02-12T03:54:43.938+00:00",
              "createdByUserId" => "3e2ed889-52f2-45ce-8a30-8767266f07d2",
              "updatedDate" => "2023-02-12T03:54:44.574+00:00",
              "updatedByUserId" => "3e2ed889-52f2-45ce-8a30-8767266f07d2"}
          }
        ],
       "totalRecords" => 2}
    }

    it "raises a MultipleRecordsForIdentifier exception" do
      expect { source_storage.fetch_marc_hash(instance_hrid:) }.to raise_error(FolioClient::MultipleResourcesFound, "Expected 1 record for #{instance_hrid}, but found 2")
    end
  end
end
