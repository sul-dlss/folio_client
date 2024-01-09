# frozen_string_literal: true

class FolioClient
  # Lookup records in Folio Source Storage
  class SourceStorage
    FIELDS_TO_REMOVE = %w[001 003].freeze

    # get marc bib data from folio given an instance HRID
    # @param instance_hrid [String] the key to use for MARC lookup
    # @return [Hash] hash representation of the MARC. should be usable by MARC::Record.new_from_hash (from ruby-marc gem)
    # @raise [ResourceNotFound]
    # @raise [MultipleResourcesFound]
    def fetch_marc_hash(instance_hrid:)
      response_hash = client.get('/source-storage/source-records', { instanceHrid: instance_hrid })

      record_count = response_hash['totalRecords']
      raise ResourceNotFound, "No records found for #{instance_hrid}" if record_count.zero?

      if record_count > 1
        raise MultipleResourcesFound,
              "Expected 1 record for #{instance_hrid}, but found #{record_count}"
      end

      response_hash['sourceRecords'].first['parsedRecord']['content']
    end

    # get marc bib data as MARCXML from folio given an instance HRID
    # @param instance_hrid [String] the instance HRID to use for MARC lookup
    # @param barcode [String] the barcode to use for MARC lookup
    # @return [String] MARCXML string
    # @raise [ResourceNotFound]
    # @raise [MultipleResourcesFound]
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    def fetch_marc_xml(instance_hrid: nil, barcode: nil)
      if barcode.nil? && instance_hrid.nil?
        raise ArgumentError,
              'Either a barcode or a Folio instance HRID must be provided'
      end

      instance_hrid ||= client.fetch_hrid(barcode: barcode)

      if instance_hrid.blank?
        raise ResourceNotFound,
              "Catalog record not found. HRID: #{instance_hrid} | Barcode: #{barcode}"
      end

      marc_record = MARC::Record.new_from_hash(
        fetch_marc_hash(instance_hrid: instance_hrid)
      )
      updated_marc = MARC::Record.new
      updated_marc.leader = marc_record.leader
      marc_record.fields.each do |field|
        # explicitly remove all listed tags from the record
        next if FIELDS_TO_REMOVE.include?(field.tag)

        updated_marc.fields << field
      end
      # explicitly inject the instance_hrid into the 001 field
      updated_marc.fields << MARC::ControlField.new('001', instance_hrid)
      # explicitly inject FOLIO into the 003 field
      updated_marc.fields << MARC::ControlField.new('003', 'FOLIO')
      updated_marc.to_xml.to_s
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize

    private

    def client
      FolioClient.instance
    end
  end
end
