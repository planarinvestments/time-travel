require 'rails_helper'

describe TimeTravel do

  let(:balance_klass) do
    Class.new(ActiveRecord::Base) do
      self.table_name = 'balances'
      include TimeTravel::TimelineHelper

      def self.timeline_fields
        [ :cash_account_id ]
      end

      def self.batch_size
        1000
      end
    end
  end

  let(:effective_from) { Date.yesterday.end_of_day.change(nsec: 0) }
  let(:cash_account_id) { 1 }
  let(:effective_till) { effective_from + 10.minutes }
  let(:amount) { 50 }

  context 'multiple identifiers and batch size not defined' do
    let(:entry_klass) do
      Class.new(ActiveRecord::Base) do
        self.table_name = 'blocked_entries'
        include TimeTravel::TimelineHelper

        def self.time_travel_identifiers
          [:wrapper_id, :req_id, :req_type]
        end
      end
    end

    let(:req_id) { 1 }
    let(:req_type) { 'TYPE' }
    let(:wrapper_id) { 1 }

    describe 'create' do
      it "creates new record with timestamps set" do
        timeline=entry_klass.timeline(wrapper_id: wrapper_id, req_id: req_id, req_type: req_type)
        attrs= { amount: amount }
        timeline.create_or_update(attrs, effective_from: effective_from, effective_till: TimeTravel::INFINITE_DATE)
        table=timeline.at(effective_from)
        expect(table).to be_persisted
        expect(table.req_type).to eql(req_type)
        expect(table.req_id).to eql(req_id)
        expect(table.effective_from).to eql(effective_from)
        expect(table.effective_till).to eql(TimeTravel::INFINITE_DATE)
        expect(table).to be_valid_now
      end

      it "creates new record with timestamps set to default" do
        timeline=entry_klass.timeline(wrapper_id: wrapper_id, req_id: req_id, req_type: req_type)
        attrs = { amount: amount }
        timeline.create_or_update(attrs)
        table=timeline.at(Time.current)
        expect(table).to be_persisted
        expect(table.amount).to eql(amount)
        expect(table.req_id).to eql(req_id)
        expect(table.effective_from).to be_present
        expect(table).to be_effective_now
        expect(table).to be_valid_now
        expect(table.effective_from).to eql(table.valid_from)
      end
    end

    describe 'delete' do
      let(:deleted_time) { effective_till }

      it "makes current effective record ineffective" do
        current_time=Time.current
        timeline=entry_klass.timeline(wrapper_id: wrapper_id, req_id: req_id, req_type: req_type)
        attrs= { amount: amount }
        timeline.create_or_update(attrs, effective_from: effective_from, effective_till: TimeTravel::INFINITE_DATE)
        timeline.terminate(effective_till: current_time)
        entry_history = timeline.at(current_time)
        expect(entry_history).to eql(nil)
        entry_history = timeline.at(current_time - 1.hour)
        expect(entry_history.amount).to eq(amount)
        expect(entry_history.wrapper_id).to eq(wrapper_id)
        expect(entry_history.req_id).to eq(req_id)
        expect(entry_history.req_type).to eq(req_type)
      end

      it "reports error when there is no effective record found" do
        timeline=entry_klass.timeline(wrapper_id: wrapper_id, req_id: req_id, req_type: req_type)
        timeline.create_or_update(amount: amount, req_id: req_id, req_type: req_type, wrapper_id: wrapper_id,
          effective_from: effective_from, effective_till: deleted_time)
        expect {
          timeline.terminate(effective_till: deleted_time)
        }.to raise_error("no effective record found on timeline")
      end
    end
  end

  describe "#create" do
    describe "validations" do
      it "raises error when valid_from is set" do
        balance = balance_klass.create(valid_from: Time.current)
        expect(balance).to be_invalid
        expect(balance.errors.full_messages).to include("valid_from and valid_till can't be set")
      end

      it "raises error when valid_till is set" do
        balance = balance_klass.create(valid_till: Time.current)
        expect(balance).to be_invalid
        expect(balance.errors.full_messages).to include("valid_from and valid_till can't be set")
      end

      it "raises error when effective_from is greater than effective_till" do
        balance = balance_klass.create(effective_from: effective_till, effective_till: effective_from)
        expect(balance).to be_invalid
        expect(balance.errors.full_messages).to include("effective_from can't be greater than effective_till")
      end

      it "raises error when identifier is already present" do
        timeline=balance_klass.timeline(cash_account_id: cash_account_id)
        attrs={ amount: amount }
        timeline.create(attrs)
        expect {
          timeline.create(attrs)
        }.to raise_error("timeline already exists")
      end
    end

    it "creates new record with timestamps set" do
      timeline=balance_klass.timeline(cash_account_id: cash_account_id)
      attrs = { amount: amount }
      timeline.create(attrs, effective_from: effective_from, effective_till: effective_till)
      balance=timeline.at(effective_from)
      expect(balance).to be_persisted
      expect(balance.amount).to eql(amount)
      expect(balance.cash_account_id).to eql(cash_account_id)
      expect(balance.effective_from).to eql(effective_from)
      expect(balance.effective_till).to eql(effective_till)
      expect(balance).to be_valid_now
    end

    it "creates new record with timestamps set to default" do
      timeline=balance_klass.timeline(cash_account_id: cash_account_id)
      attrs = { amount: amount }
      timeline.create(attrs)
      balance=timeline.at(Time.current)
      expect(balance).to be_persisted
      expect(balance.amount).to eql(amount)
      expect(balance.cash_account_id).to eql(cash_account_id)
      expect(balance.effective_from).to be_present
      expect(balance).to be_effective_now
      expect(balance).to be_valid_now
      expect(balance.effective_from).to eql(balance.valid_from)
    end
  end

  describe "#delete" do
    let(:deleted_time) { Time.now.round }

    it "makes current effective record ineffective" do
      timeline=balance_klass.timeline(cash_account_id: cash_account_id)
      attrs = { amount: amount }
      timeline.create(attrs, effective_from: effective_from)
      timeline.terminate(effective_till: deleted_time)

      balance_history = timeline.effective_history
      expect(balance_history.count).to eql(1)

      expect(balance_history[0].amount).to eql(amount)
      expect(balance_history[0].cash_account_id).to eql(cash_account_id)
      expect(balance_history[0].effective_from.strftime('%c')).to eql(effective_from.utc.strftime('%c'))
      expect(balance_history[0].effective_till).to eql(deleted_time)
      expect(balance_history[0]).to be_valid_now
    end

    it "reports error when there is no effective record found" do
      timeline=balance_klass.timeline(cash_account_id: cash_account_id)
      attrs = { amount: amount }
      timeline.create(attrs, effective_from: effective_from, effective_till: effective_till)
      expect {
        timeline.terminate(effective_till: deleted_time)
      }.to raise_error("no effective record found on timeline")

      balance_history = timeline.effective_history
      expect(balance_history.count).to eql(1)

      expect(balance_history[0].amount).to eql(amount)
      expect(balance_history[0].cash_account_id).to eql(cash_account_id)
      expect(balance_history[0].effective_from).to be_present
      expect(balance_history[0].effective_till.strftime('%c')).to eql(effective_till.utc.strftime('%c'))
      expect(balance_history[0]).to be_valid_now
    end
  end

  describe "#effective_now" do
    it 'returns records only effective_now' do
      balance = balance_klass.create(amount: amount, cash_account_id: cash_account_id,
                 effective_from: effective_from, effective_till: effective_till)
      balance.update!(amount: 121, effective_from: effective_till,effective_till: TimeTravel::INFINITE_DATE)
      expect(balance_klass.effective_now.count).to eql(1)
      expect(balance_klass.effective_now.first.amount).to eql(121)
    end
  end
end
