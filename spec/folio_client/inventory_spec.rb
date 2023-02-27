# frozen_string_literal: true

RSpec.describe FolioClient::Inventory do
  subject(:inventory) do
    described_class.new(client)
  end

  let(:args) { {url:, login_params:, okapi_headers:} }
  let(:url) { "https://folio.example.org" }
  let(:login_params) { {username: "username", password: "password"} }
  let(:okapi_headers) { {some_bogus_headers: "here"} }
  let(:token) { "a_long_silly_token" }
  let(:client) { FolioClient.configure(**args) }
  let(:barcode) { "123456" }
  let(:instance_uuid) { "some_long_uuid_that_is_long" }
  let(:hrid) { "a12854819" }

  before do
    stub_request(:post, "#{url}/authn/login")
      .to_return(status: 200, body: "{\"okapiToken\" : \"#{token}\"}")
  end

  context "when looking up a barcode" do
    before do
      stub_request(:get, "#{url}/search/instances?query=items.barcode==#{barcode}")
        .to_return(status: 200, body: search_instance_response.to_json)
      stub_request(:get, "#{url}/inventory/instances/#{instance_uuid}")
        .to_return(status: 200, body: inventory_instance_response.to_json)
    end

    context "when barcode is found and search for instance_uuid returns a result" do
      let(:search_instance_response) {
        {"totalRecords" => 1,
         "instances" => [
           {"id" => instance_uuid,
            "title" => "Training videos",
            "contributors" => [{"name" => "Person"}],
            "isBoundWith" => false,
            "holdings" => []}
         ]}
      }
      let(:inventory_instance_response) {
        {"id" => "d71e654b-ca5e-44c0-9621-ae86ffd528d3",
         "_version" => "1",
         "hrid" => hrid,
         "source" => "FOLIO",
         "title" => "Training videos",
         "isBoundWith" => false,
         "contributors" => [],
         "publication" => [],
         "electronicAccess" => [],
         "instanceTypeId" => "225faa14-f9bf-4ecd-990d-69433c912434",
         "statusId" => "2a340d34-6b70-443a-bb1b-1b8d1c65d862",
         "statusUpdatedDate" => "2023-02-10T21:19:22.285+0000",
         "metadata" => {},
         "succeedingTitles" => []}
      }

      it "returns the instance hrid" do
        expect(inventory.fetch_hrid(barcode:)).to eq(hrid)
      end
    end

    context "when barcode is not found" do
      let(:search_instance_response) {
        {"totalRecords" => 0,
         "instances" => []}
      }
      let(:inventory_instance_response) {}

      it "returns nil" do
        expect(inventory.fetch_hrid(barcode:)).to be_nil
      end
    end

    context "when barcode is found but search for instance_uuid returns no results" do
      let(:search_instance_response) {
        {"totalRecords" => 1,
         "instances" => [
           {"id" => instance_uuid,
            "title" => "Training videos",
            "contributors" => [{"name" => "Person"}],
            "isBoundWith" => false,
            "holdings" => []}
         ]}
      }
      let(:inventory_instance_response) { {} }

      it "returns nil" do
        expect(inventory.fetch_hrid(barcode:)).to be_nil
      end
    end
  end

  context "when checking whether an item is cataloged" do
    let(:status_id) { "1a2b3c4d-1234" }

    before do
      stub_request(:get, "#{url}/inventory/instances?query=hrid==#{hrid}")
        .to_return(status: 200, body: inventory_instance_response.to_json)
    end

    context "when instance has cataloged status" do
      let(:inventory_instance_response) {
        {"instances" => [
           {"id" => "d71e654b-ca5e-44c0-9621-ae86ffd528d3",
            "_version" => "1",
            "hrid" => hrid,
            "source" => "FOLIO",
            "title" => "Training videos",
            "isBoundWith" => false,
            "contributors" => [],
            "publication" => [],
            "electronicAccess" => [],
            "instanceTypeId" => "225faa14-f9bf-4ecd-990d-69433c912434",
            "statusId" => status_id,
            "statusUpdatedDate" => "2023-02-10T21:19:22.285+0000",
            "metadata" => {},
            "succeedingTitles" => []}
         ],
         "totalRecords" => 1}
      }

      it "returns true" do
        expect(inventory.has_instance_status?(hrid:, status_id:)).to be true
      end
    end

    context "when instance has a different status" do
      let(:inventory_instance_response) {
        {"instances" => [
           {"id" => "d71e654b-ca5e-44c0-9621-ae86ffd528d3",
            "_version" => "1",
            "hrid" => hrid,
            "source" => "FOLIO",
            "title" => "Training videos",
            "isBoundWith" => false,
            "contributors" => [],
            "publication" => [],
            "electronicAccess" => [],
            "instanceTypeId" => "225faa14-f9bf-4ecd-990d-69433c912434",
            "statusId" => "2b3c4d5e-0987",
            "statusUpdatedDate" => "2023-02-10T21:19:22.285+0000",
            "metadata" => {},
            "succeedingTitles" => []}
         ],
         "totalRecords" => 1}
      }

      it "returns false" do
        expect(inventory.has_instance_status?(hrid:, status_id:)).to be false
      end
    end

    context "when instance has no status" do
      let(:inventory_instance_response) {
        {"instances" => [
           {"id" => "d71e654b-ca5e-44c0-9621-ae86ffd528d3",
            "_version" => "1",
            "hrid" => hrid,
            "source" => "FOLIO",
            "title" => "Training videos",
            "isBoundWith" => false,
            "contributors" => [],
            "publication" => [],
            "electronicAccess" => [],
            "instanceTypeId" => "225faa14-f9bf-4ecd-990d-69433c912434",
            "metadata" => {},
            "succeedingTitles" => []}
         ],
         "totalRecords" => 1}
      }

      it "returns false" do
        expect(inventory.has_instance_status?(hrid:, status_id:)).to be false
      end
    end

    context "when no matching instance found" do
      let(:inventory_instance_response) {
        {"totalRecords" => 0,
         "instances" => []}
      }

      it "raises an error" do
        expect { inventory.has_instance_status?(hrid:, status_id:) }.to raise_error(FolioClient::ResourceNotFound, "No matching instance found for #{hrid}")
      end
    end
  end
end
