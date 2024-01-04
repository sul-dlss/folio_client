# frozen_string_literal: true

RSpec.describe FolioClient::RecordsEditor do
  subject(:records_editor) { described_class.new(client) }

  let(:args) { { url: url, login_params: login_params, okapi_headers: okapi_headers } }
  let(:url) { 'https://folio.example.org' }
  let(:login_params) { { username: 'username', password: 'password' } }
  let(:okapi_headers) { { some_bogus_headers: 'here' } }
  let(:token) { 'aLongSTring.eNCodinga.JwTeeeee' }
  let(:client) { FolioClient.configure(**args) }
  let(:hrid) { 'in00000000067' }
  let(:external_id) { '5108040a-65bc-40ed-bd50-265958301ce4' }

  let(:mock_response_json) do
    { 'parsedRecordId' => '1ab23862-46db-4da9-af5b-633adbf5f90f',
      'parsedRecordDtoId' => '1281ae0b-548b-49e3-b740-050f28e6d57f',
      'suppressDiscovery' => false,
      'marcFormat' => 'BIBLIOGRAPHIC',
      'externalId' => '5108040a-65bc-40ed-bd50-265958301ce4',
      'externalHrid' => 'in00000000067',
      'leader' => '01654nam\\a22003253i\\4500',
      'fields' =>
      [{ 'tag' => '001', 'content' => 'in00000000067', 'isProtected' => true },
       { 'tag' => '006', 'content' => { 'Type' => 'm', 'Audn' => '\\', 'Form' => '\\', 'File' => 'd', 'GPub' => '\\' },
         'isProtected' => false },
       { 'tag' => '007',
         'content' =>
         { '$categoryName' => 'Electronic resource', 'Category' => 'c', 'SMD' => 'r',
           'Color' => 'u', 'Dimensions' => 'n', 'Sound' => '\\', 'Image bit depth' => '\\\\\\', 'File formats' => '\\',
           'Quality assurance target(s)' => '\\',
           'Antecedent/ Source' => '\\', 'Level of compression' => '\\', 'Reformatting quality' => '\\' },
         'isProtected' => false },
       { 'tag' => '008',
         'content' =>
         { 'Type' => 'a', 'BLvl' => 'm', 'Entered' => '200417', 'DtSt' => 't', 'Date1' => '2020', 'Date2' => '2020',
           'Ctry' => 'cau', 'Lang' => 'eng', 'MRec' => '\\', 'Srce' => 'd',
           'Ills' => ['\\', '\\', '\\', '\\'], 'Audn' => '\\', 'Form' => 'o', 'Cont' => ['m', '\\', '\\', '\\'],
           'GPub' => '\\', 'Conf' => '0', 'Fest' => '0', 'Indx' => '0', 'LitF' => '0', 'Biog' => '\\' },
         'isProtected' => false },
       { 'tag' => '005', 'content' => '20230303155934.8', 'isProtected' => false },
       { 'tag' => '035', 'content' => '$a dorcg532dg5405', 'indicators' => ['\\', '\\'], 'isProtected' => false },
       { 'tag' => '040', 'content' => '$a CSt $b eng $e rda $c CSt', 'indicators' => ['\\', '\\'],
         'isProtected' => false },
       { 'tag' => '100', 'content' => '$a Name, Author, $e author.', 'indicators' => ['1', '\\'],
         'isProtected' => false },
       { 'tag' => '245',
         'content' => '$a Original Title: Before Update / $c Author Name.',
         'indicators' => %w[1 0],
         'isProtected' => false },
       { 'tag' => '264',
         'content' => '$a [Stanford, California] : $b [Stanford University], $c 2020.',
         'indicators' => ['\\', '1'],
         'isProtected' => false },
       { 'tag' => '264', 'content' => '$c ©2020', 'indicators' => ['\\', '4'], 'isProtected' => false },
       { 'tag' => '300', 'content' => '$a 1 online resource.', 'indicators' => ['\\', '\\'], 'isProtected' => false },
       { 'tag' => '336', 'content' => '$a text $2 rdacontent', 'indicators' => ['\\', '\\'], 'isProtected' => false },
       { 'tag' => '337', 'content' => '$a computer $2 rdamedia', 'indicators' => ['\\', '\\'], 'isProtected' => false },
       { 'tag' => '338', 'content' => '$a online resource $2 rdacarrier', 'indicators' => ['\\', '\\'],
         'isProtected' => false },
       { 'tag' => '520',
         'content' => '$a Convex optimization has been well-studied as a mathematical topic for more than a century, and has been applied in ' \
                      'practice in many application areas for about a half century in fields including control, finance, signal processing, ' \
                      'data mining, and machine learning. This thesis focuses on several topics involving convex optimization, ' \
                      'with the specific application of machine learning.',
         'indicators' => ['3', '\\'],
         'isProtected' => false },
       { 'tag' => '700',
         'content' => '$a Boyd, Stephen, $e degree supervisor. $4 ths',
         'indicators' => ['1', '\\'],
         'isProtected' => false },
       { 'tag' => '700',
         'content' => '$a Leskovec, Jure, $e degree committee member. $4 ths',
         'indicators' => ['1', '\\'],
         'isProtected' => false },
       { 'tag' => '710',
         'content' => '$a Stanford University. $b Department of Electrical Engineering.',
         'indicators' => ['2', '\\'],
         'isProtected' => false },
       { 'tag' => '856', 'content' => '$u https://purl.stanford.edu/cg532dg5405', 'indicators' => %w[4 0],
         'isProtected' => false },
       { 'tag' => '910', 'content' => '$a https://etd.stanford.edu/view/0000007573', 'indicators' => ['\\', '\\'],
         'isProtected' => true },
       { 'tag' => '999',
         'content' => '$s 1281ae0b-548b-49e3-b740-050f28e6d57f $i 5108040a-65bc-40ed-bd50-265958301ce4',
         'indicators' => %w[f f],
         'isProtected' => true }],
      'updateInfo' =>
      { 'recordState' => 'ERROR',
        'updateDate' => '2023-03-03T15:59:35.511Z',
        'updatedBy' =>
        { 'userId' => '297649ab-3f9e-5ece-91a3-25cf700062ae', 'username' => 'app_sdr', 'firstName' => 'sdr',
          'lastName' => 'App' } } }
  end

  before do
    stub_request(:post, "#{url}/authn/login")
      .to_return(status: 200, body: "{\"okapiToken\" : \"#{token}\"}")
    allow(client).to receive(:fetch_instance_info).with(hrid: hrid).and_return({ '_version' => 1, 'id' => external_id })
    allow(client).to receive(:get).with('/records-editor/records',
                                        { externalId: external_id }).and_return(mock_response_json)
    allow(client).to receive(:put)
  end

  # rubocop:disable RSpec/ExampleLength
  it 'obtains the MARC JSON, yields it to the caller, and PUTs the edited JSON back to Folio (inserting version for optimistic locking)' do
    records_editor.edit_marc_json(hrid: hrid) do |editable_response_json|
      expect(editable_response_json).to eq mock_response_json
      editable_response_json['fields'].detect do |field|
        field['tag'] == '245'
      end['content'] = '$a title updated by unit test / $c Author Name.'
    end
    expect(client).to have_received(:put).with(
      "/records-editor/records/#{mock_response_json['parsedRecordId']}",
      hash_including({ 'parsedRecordId' => '1ab23862-46db-4da9-af5b-633adbf5f90f',
                       'parsedRecordDtoId' => '1281ae0b-548b-49e3-b740-050f28e6d57f',
                       'relatedRecordVersion' => 1,
                       'externalId' => '5108040a-65bc-40ed-bd50-265958301ce4',
                       'externalHrid' => 'in00000000067',
                       'fields' => array_including({ 'tag' => '245', 'content' => '$a title updated by unit test / $c Author Name.',
                                                     'indicators' => %w[1 0], 'isProtected' => false }) })
    )
  end
  # rubocop:enable RSpec/ExampleLength
end
