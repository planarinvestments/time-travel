require 'rails_helper'

describe UpdateHelper do
  before(:all) do
    ActiveRecord::Base.establish_connection(adapter:  'sqlite3', database: ':memory:')
    ActiveRecord::Base.connection.create_table :balances do |t|
      t.integer :cash_account_id
      t.integer :amount
      t.datetime :effective_from
      t.datetime :effective_till
      t.datetime :valid_from
      t.datetime :valid_till
    end
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :balances
  end

  let(:aug_25) { Date.parse('25/08/2018').beginning_of_day }
  let(:aug_28) { Date.parse('28/08/2018').beginning_of_day }
  let(:sep_2) { Date.parse('02/09/2018').beginning_of_day }
  let(:sep_5) { Date.parse('05/09/2018').beginning_of_day }
  let(:sep_6) { Date.parse('06/09/2018').beginning_of_day }
  let(:sep_8) { Date.parse('08/09/2018').beginning_of_day }
  let(:sep_10) { Date.parse('10/09/2018').beginning_of_day }
  let(:sep_12) { Date.parse('12/09/2018').beginning_of_day }
  let(:sep_14) { Date.parse('14/09/2018').beginning_of_day }
  let(:sep_15) { Date.parse('15/09/2018').beginning_of_day }
  let(:sep_19) { Date.parse('19/09/2018').beginning_of_day }
  let(:sep_20) { Date.parse('20/09/2018').beginning_of_day }
  let(:sep_21) { Date.parse('21/09/2018').beginning_of_day }
  let(:sep_25) { Date.parse('25/09/2018').beginning_of_day }

  let(:balance_klass) do
    Class.new(ActiveRecord::Base) do
      self.table_name = 'balances'
      include TimeTravel

      def self.time_travel_identifiers
        [ :cash_account_id ]
      end
    end
  end

  let(:balance) { balance_klass.create(amount: 10, cash_account_id: 1,
      effective_from: sep_2 , effective_till: sep_5) }

  before do
    balance.update(amount: 20, effective_from: sep_5, effective_till: sep_8)
    balance.update(amount: 30, effective_from: sep_8, effective_till: sep_10)
    balance.update(amount: 40, effective_from: sep_10, effective_till: sep_15)
    balance.update(amount: 50, effective_from: sep_15, effective_till: sep_20)
    balance.update(amount: 60, effective_from: sep_20, effective_till: TimeTravel::INFINITE_DATE)
  end

  describe "fetch_history_for_correction" do
    it "returns correction head, tail, range separately" do
      balance.effective_from = sep_6
      balance.effective_till = sep_19

      records = balance.fetch_history_for_correction

      expect(records.count).to eql(4)
      expect(records[0].amount).to eql(20)
      expect(records[1].amount).to eql(30)
      expect(records[2].amount).to eql(40)
      expect(records[3].amount).to eql(50)
    end

    it "returns same correction head, tail" do
      balance.effective_from = sep_12
      balance.effective_till = sep_14

      records = balance.fetch_history_for_correction

      expect(records.count).to eql(1)
      expect(records[0].amount).to eql(40)
    end

    it "returns correction head and tail without range" do
      balance.effective_from = sep_12
      balance.effective_till = sep_19

      records = balance.fetch_history_for_correction

      expect(records.count).to eql(2)
      expect(records[0].amount).to eql(40)
      expect(records[1].amount).to eql(50)
    end
  end

  describe "get_affected_timeframes" do
    it "returns affected timeframes split across existing timeframes" do
      balance.effective_from = sep_6
      balance.effective_till = sep_19

      affected_records = balance.fetch_history_for_correction
      affected_timeframes = balance.get_affected_timeframes(affected_records)

      expect(affected_timeframes.count).to eql(6)

      affected_timeframes = affected_timeframes.map{|tf| [tf[:from].localtime, tf[:till].localtime]}
      expect(affected_timeframes[0]).to eql([sep_5, sep_6])
      expect(affected_timeframes[1]).to eql([sep_6, sep_8])
      expect(affected_timeframes[2]).to eql([sep_8, sep_10])
      expect(affected_timeframes[3]).to eql([sep_10, sep_15])
      expect(affected_timeframes[4]).to eql([sep_15, sep_19])
      expect(affected_timeframes[5]).to eql([sep_19, sep_20])
    end

    it "returns affected timeframes spliting infinite date" do
      balance.effective_from = sep_25
      balance.effective_till = TimeTravel::INFINITE_DATE

      affected_records = balance.fetch_history_for_correction
      affected_timeframes = balance.get_affected_timeframes(affected_records)

      expect(affected_timeframes.count).to eql(2)

      affected_timeframes = affected_timeframes.map{|tf| [tf[:from].localtime, tf[:till].localtime]}
      expect(affected_timeframes[0]).to eql([sep_20, sep_25])
      expect(affected_timeframes[1]).to eql([sep_25, TimeTravel::INFINITE_DATE])
    end

    it "returns affected timeframes before history" do
      balance.effective_from = aug_25
      balance.effective_till = aug_28

      affected_records = balance.fetch_history_for_correction
      affected_timeframes = balance.get_affected_timeframes(affected_records)

      expect(affected_timeframes.count).to eql(1)

      affected_timeframes = affected_timeframes.map{|tf| [tf[:from].localtime, tf[:till].localtime]}
      expect(affected_timeframes[0]).to eql([aug_25, aug_28])
    end
  end

  describe "#squish_record_history" do
    it "squish records when overlapping timeframes have same attribute values" do
      balance_1 = {cash_account_id: 1, amount: 10, effective_from: sep_2, effective_till: sep_5}
      balance_2 = {cash_account_id: 1, amount: 10, effective_from: sep_5, effective_till: sep_8}

      squished_history = balance.squish_record_history([balance_1, balance_2])

      expect(squished_history.count).to eql(1)
      expect(squished_history[0]).to eql({cash_account_id: 1, amount: 10, effective_from: sep_2, effective_till: sep_8})
    end

    it "doesn't squish records when overlapping timeframes have different attribute values" do
      balance_1 = {cash_account_id: 1, amount: 10, effective_from: sep_5, effective_till: sep_8}
      balance_2 = {cash_account_id: 1, amount: 15, effective_from: sep_8, effective_till: sep_10}

      squished_history = balance.squish_record_history([balance_1, balance_2])

      expect(squished_history.count).to eql(2)
      expect(squished_history[0]).to eql({cash_account_id: 1, amount: 10, effective_from: sep_5, effective_till: sep_8})
      expect(squished_history[1]).to eql({cash_account_id: 1, amount: 15, effective_from: sep_8, effective_till: sep_10})
    end

    it "doesn't squish when next to next records aren't overlapping but having same attribute values" do
      balance_1 = {cash_account_id: 1, amount: 10, effective_from: sep_2, effective_till: sep_5}
      balance_2 = {cash_account_id: 1, amount: 10, effective_from: sep_8, effective_till: sep_10}

      squished_history = balance.squish_record_history([balance_1, balance_2])

      expect(squished_history.count).to eql(2)
      expect(squished_history[0]).to eql({cash_account_id: 1, amount: 10, effective_from: sep_2, effective_till: sep_5})
      expect(squished_history[1]).to eql({cash_account_id: 1, amount: 10, effective_from: sep_8, effective_till: sep_10})
    end
  end

  describe "#construct_corrected_records" do
    it "builds records with updated atributes when affected and to update timeframes match" do
      balance.effective_from = sep_2
      balance.effective_till = sep_8

      affected_timeframes = [{from: sep_2, till: sep_8}]
      affected_records = [balance_klass.new(effective_from: sep_2, effective_till: sep_8,
        cash_account_id: 1, amount: 19)]
      update_attrs = {amount: 20}

      corrected_records = balance.construct_corrected_records(affected_timeframes, affected_records, update_attrs)
      expect(corrected_records.count).to eql(1)
      expect(corrected_records[0][:amount]).to eql(20)
      expect(corrected_records[0][:cash_account_id]).to eql(1)
      expect(corrected_records[0][:effective_from]).to eql(sep_2)
      expect(corrected_records[0][:effective_till]).to eql(sep_8)
    end

    it "builds records with both updated and retained attributes for respective timeframes" do
      balance.effective_from = sep_12
      balance.effective_till = sep_14

      affected_timeframes = [{from: sep_10, till: sep_12}, {from: sep_12, till: sep_14},
          {from: sep_14, till: sep_15}]
      affected_records = [balance_klass.new(effective_from: sep_10, effective_till: sep_15,
        cash_account_id: 1, amount: 40)]
      update_attrs = {amount: 30}

      corrected_records = balance.construct_corrected_records(affected_timeframes, affected_records, update_attrs)
      expect(corrected_records.count).to eql(3)

      expect(corrected_records[0][:amount]).to eql(40)
      expect(corrected_records[0][:cash_account_id]).to eql(1)
      expect(corrected_records[0][:effective_from]).to eql(sep_10)
      expect(corrected_records[0][:effective_till]).to eql(sep_12)

      expect(corrected_records[1][:amount]).to eql(30)
      expect(corrected_records[1][:cash_account_id]).to eql(1)
      expect(corrected_records[1][:effective_from]).to eql(sep_12)
      expect(corrected_records[1][:effective_till]).to eql(sep_14)

      expect(corrected_records[2][:amount]).to eql(40)
      expect(corrected_records[2][:cash_account_id]).to eql(1)
      expect(corrected_records[2][:effective_from]).to eql(sep_14)
      expect(corrected_records[2][:effective_till]).to eql(sep_15)
    end

    it "builds records when even when no matching timeframes present" do
      balance.effective_from = sep_12
      balance.effective_till = sep_14

      affected_timeframes = [{from: sep_12, till: sep_14}]
      affected_records = []
      update_attrs = {amount: 30}

      corrected_records = balance.construct_corrected_records(affected_timeframes, affected_records, update_attrs)
      expect(corrected_records.count).to eql(1)

      expect(corrected_records[0][:amount]).to eql(30)
      expect(corrected_records[0][:cash_account_id]).to eql(1)
      expect(corrected_records[0][:effective_from]).to eql(sep_12)
      expect(corrected_records[0][:effective_till]).to eql(sep_14)
    end
  end
end
