# frozen_string_literal: true

RSpec.describe FolioClient::JobStatus do
  include Dry::Monads[:result]

  let(:job_status) { described_class.new(client, job_execution_id: job_execution_id) }
  let(:client) do
    FolioClient.configure(
      url: url,
      login_params: {username: "username", password: "password"},
      okapi_headers: {some_bogus_headers: "here"}
    )
  end
  let(:job_execution_id) { "4ba4f4ab" }
  let(:token) { "a temporary dummy token to avoid hitting the API before it is needed" }
  let(:url) { "https://folio.example.org" }

  before do
    stub_request(:post, "#{url}/authn/login")
      .to_return(status: 200, body: "{\"okapiToken\" : \"#{token}\"}")
    allow(DateTime).to receive(:now).and_return(DateTime.parse("2023-03-01T11:17:25-05:00"))
  end

  describe "#job_execution_id" do
    it "returns the job execution ID" do
      expect(job_status.job_execution_id).to eq(job_execution_id)
    end
  end

  describe "#status" do
    before do
      stub_request(:get, "#{url}/change-manager/jobExecutions/#{job_execution_id}")
        .with(
          headers: {
            "X-Okapi-Token" => token
          }
        )
        .to_return(status: status, body: status_response_body.to_json, headers: {})
    end

    let(:status) { 200 }

    context "when job is pending" do
      let(:status_response_body) do
        {
          id: job_execution_id,
          status: "PARSING_IN_PROGRESS"
        }
      end

      it "returns Failure(:pending)" do
        expect(job_status.status).to eq(Failure(:pending))
      end
    end

    context "when job error" do
      let(:status_response_body) do
        {
          id: job_execution_id,
          status: "ERROR"
        }
      end

      it "returns Success()" do
        expect(job_status.status).to eq(Success())
      end
    end

    context "when job is complete" do
      let(:status_response_body) do
        {
          id: job_execution_id,
          status: "COMMITTED"
        }
      end

      it "returns Success" do
        expect(job_status.status).to eq(Success())
      end
    end

    context "when job is not found" do
      let(:status) { 404 }
      let(:status_response_body) { "JobSummary for jobExecutionId: '#{job_execution_id}' was not found" }

      it "returns Failure(:not_found)" do
        expect(job_status.status).to eq(Failure(:not_found))
      end
    end
  end

  describe "#wait_until_complete" do
    context "when job is complete" do
      before do
        allow(job_status).to receive(:status).and_return(Failure(:not_found), Failure(:pending), Success())
      end

      it "returns Success" do
        expect(job_status.wait_until_complete(wait_secs: 0.1)).to eq(Success())
        expect(job_status).to have_received(:status).exactly(3).times
      end
    end

    context "when job is error" do
      before do
        allow(job_status).to receive(:status).and_return(Failure(:pending), Failure(:pending), Failure(:error))
      end

      it "returns Failure(:error)" do
        expect(job_status.wait_until_complete(wait_secs: 0.1)).to eq(Failure(:error))
        expect(job_status).to have_received(:status).exactly(3).times
      end
    end

    context "when too many 404s" do
      before do
        allow(job_status).to receive(:status).and_return(Failure(:not_found))
      end

      it "raises ResourceNotFound" do
        expect { job_status.wait_until_complete(wait_secs: 0.1) }.to raise_error(FolioClient::ResourceNotFound)
        expect(job_status).to have_received(:status).exactly(4).times
      end
    end

    context "when timeout" do
      before do
        allow(job_status).to receive(:status).and_return(Failure(:pending))
      end

      it "returns Failure(:timeout)" do
        expect(job_status.wait_until_complete(wait_secs: 0.5, timeout_secs: 0.25)).to eq(Failure(:timeout))
      end
    end
  end

  describe "#instance_hrids" do
    before do
      allow(job_status).to receive(:status).and_return(current_status)
      allow(job_status).to receive(:default_timeout_secs).and_return(1)
      stub_request(:get, "#{url}/metadata-provider/journalRecords/#{job_execution_id}")
        .with(
          headers: {
            "X-Okapi-Token" => token
          }
        )
        .to_return(status: status, body: journal_records_response.to_json, headers: {})
    end

    let(:current_status) { Success() }
    let(:status) { 200 }
    let(:journal_records_response) do
      {
        journalRecords: [
          {
            id: "ac01df37-1bec-4e61-bca8-d2932881c253",
            jobExecutionId: "0087063f-73ff-4a52-8890-f318771963e4",
            sourceId: "6faca97d-d081-4f19-8d2b-5e17ce32fd57",
            sourceRecordOrder: 0,
            entityType: "MARC_BIBLIOGRAPHIC",
            entityId: "6faca97d-d081-4f19-8d2b-5e17ce32fd57",
            entityHrId: "",
            actionType: "CREATE",
            actionStatus: "COMPLETED",
            error: "",
            title: "TEST5: TOPICS IN CONVEX OPTIMIZATION FOR MACHINE LEARNING / Youngsuk Park.",
            actionDate: "2023-02-16T18:14:46.032+00:00"
          },
          {
            id: "a61f5475-c612-4df2-8bec-e1775c06093d",
            jobExecutionId: "0087063f-73ff-4a52-8890-f318771963e4",
            sourceId: "6faca97d-d081-4f19-8d2b-5e17ce32fd57",
            sourceRecordOrder: 0,
            entityType: "MARC_BIBLIOGRAPHIC",
            entityId: "6faca97d-d081-4f19-8d2b-5e17ce32fd57",
            entityHrId: "",
            actionType: "CREATE",
            actionStatus: "COMPLETED",
            error: "",
            title: "TEST5: TOPICS IN CONVEX OPTIMIZATION FOR MACHINE LEARNING / Youngsuk Park.",
            actionDate: "2023-02-16T18:14:53.323+00:00"
          },
          {
            id: "1e699607-59a0-4620-a620-2004e49c3bb7",
            jobExecutionId: "0087063f-73ff-4a52-8890-f318771963e4",
            sourceId: "6faca97d-d081-4f19-8d2b-5e17ce32fd57",
            sourceRecordOrder: 0,
            entityType: "INSTANCE",
            entityId: "45e401f8-ae58-42a5-9ccc-cc020cac7c3e",
            entityHrId: "in00000000010",
            actionType: "CREATE",
            actionStatus: "COMPLETED",
            error: "",
            actionDate: "2023-02-16T18:14:53.444+00:00"
          },
          {
            id: "45b2cec6-b681-4913-ac59-30bfdac1407d",
            jobExecutionId: "0087063f-73ff-4a52-8890-f318771963e4",
            sourceId: "6faca97d-d081-4f19-8d2b-5e17ce32fd57",
            sourceRecordOrder: 0,
            entityType: "HOLDINGS",
            entityId: "f45c450f-d06c-452a-9e24-55551dcb2047",
            instanceId: "45e401f8-ae58-42a5-9ccc-cc020cac7c3e",
            entityHrId: "ho00000000008",
            actionType: "CREATE",
            actionStatus: "COMPLETED",
            error: "",
            title: "TEST5: TOPICS IN CONVEX OPTIMIZATION FOR MACHINE LEARNING / Youngsuk Park.",
            actionDate: "2023-02-16T18:14:55.714+00:00"
          }
        ],
        totalRecords: 4
      }
    end

    it "returns Success with the instance HRID" do
      expect(job_status.instance_hrids).to eq(Success(["in00000000010"]))
    end

    context "when current status is not successful" do
      let(:current_status) { Failure(:pending) }

      it "returns the current status" do
        expect(job_status.instance_hrids).to eq(current_status)
      end
    end

    context "when journal records request returns an error response" do
      let(:journal_records_response) { {} }
      let(:status) { 404 }

      it "raises ResourceNotFound" do
        expect { job_status.instance_hrids }.to raise_error(FolioClient::ResourceNotFound, /Endpoint not found/)
      end
    end

    context "when journal records request returns no journal records" do
      let(:journal_records_response) do
        {
          journalRecords: [],
          totalRecords: 0
        }
      end

      it "returns Failure indicating timeout" do
        expect(job_status.instance_hrids).to eq(Failure(:timeout))
      end
    end

    context "when journal records request returns empty response" do
      let(:journal_records_response) { {} }

      it "returns Failure indicating timeout" do
        expect(job_status.instance_hrids).to eq(Failure(:timeout))
      end
    end

    context "when journal records request does not include an INSTANCE type" do
      let(:journal_records_response) do
        {
          journalRecords: [
            {
              id: "ac01df37-1bec-4e61-bca8-d2932881c253",
              jobExecutionId: "0087063f-73ff-4a52-8890-f318771963e4",
              sourceId: "6faca97d-d081-4f19-8d2b-5e17ce32fd57",
              sourceRecordOrder: 0,
              entityType: "MARC_BIBLIOGRAPHIC",
              entityId: "6faca97d-d081-4f19-8d2b-5e17ce32fd57",
              entityHrId: "",
              actionType: "CREATE",
              actionStatus: "COMPLETED",
              error: "",
              title: "TEST5: TOPICS IN CONVEX OPTIMIZATION FOR MACHINE LEARNING / Youngsuk Park.",
              actionDate: "2023-02-16T18:14:46.032+00:00"
            },
            {
              id: "a61f5475-c612-4df2-8bec-e1775c06093d",
              jobExecutionId: "0087063f-73ff-4a52-8890-f318771963e4",
              sourceId: "6faca97d-d081-4f19-8d2b-5e17ce32fd57",
              sourceRecordOrder: 0,
              entityType: "MARC_BIBLIOGRAPHIC",
              entityId: "6faca97d-d081-4f19-8d2b-5e17ce32fd57",
              entityHrId: "",
              actionType: "CREATE",
              actionStatus: "COMPLETED",
              error: "",
              title: "TEST5: TOPICS IN CONVEX OPTIMIZATION FOR MACHINE LEARNING / Youngsuk Park.",
              actionDate: "2023-02-16T18:14:53.323+00:00"
            },
            {
              id: "45b2cec6-b681-4913-ac59-30bfdac1407d",
              jobExecutionId: "0087063f-73ff-4a52-8890-f318771963e4",
              sourceId: "6faca97d-d081-4f19-8d2b-5e17ce32fd57",
              sourceRecordOrder: 0,
              entityType: "HOLDINGS",
              entityId: "f45c450f-d06c-452a-9e24-55551dcb2047",
              instanceId: "45e401f8-ae58-42a5-9ccc-cc020cac7c3e",
              entityHrId: "ho00000000008",
              actionType: "CREATE",
              actionStatus: "COMPLETED",
              error: "",
              title: "TEST5: TOPICS IN CONVEX OPTIMIZATION FOR MACHINE LEARNING / Youngsuk Park.",
              actionDate: "2023-02-16T18:14:55.714+00:00"
            }
          ],
          totalRecords: 3
        }
      end

      it "returns Failure indicating no instance HRID" do
        expect(job_status.instance_hrids).to eq(Failure(:timeout))
      end
    end
  end
end
