require 'rails_helper'

describe TimeTravel do
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

  let(:balance_klass) do
    Class.new(ActiveRecord::Base) do
      self.table_name = 'balances'
      include TimeTravel

      def self.time_travel_identifiers
        [ :cash_account_id ]
      end
    end
  end

  let(:effective_from) { Date.yesterday.end_of_day }
  let(:cash_account_id) { 1 }
  let(:effective_till) { effective_from + 10.minutes }
  let(:amount) { 50 }

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
        balance_klass.create(amount: amount, cash_account_id: cash_account_id)
        balance = balance_klass.create(amount: amount, cash_account_id: cash_account_id)
        expect(balance).to be_invalid
        expect(balance.errors.full_messages).to include("already has history")
      end
    end

    it "creates new record with timestamps set" do
      balance = balance_klass.create(amount: amount, cash_account_id: cash_account_id,
                 effective_from: effective_from, effective_till: effective_till)

      expect(balance).to be_persisted
      expect(balance.amount).to eql(amount)
      expect(balance.cash_account_id).to eql(cash_account_id)
      expect(balance.effective_from).to eql(effective_from)
      expect(balance.effective_till).to eql(effective_till)
      expect(balance).to be_valid_now
    end

    it "creates new record with timestamps set to default" do
      balance = balance_klass.create(amount: amount, cash_account_id: cash_account_id)

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
      balance = balance_klass.create(amount: amount, cash_account_id: cash_account_id,
                 effective_from: effective_from)
      balance.delete(effective_till: deleted_time)

      balance_history = balance_klass.history(cash_account_id)
      expect(balance_history.count).to eql(1)

      expect(balance_history[0].amount).to eql(amount)
      expect(balance_history[0].cash_account_id).to eql(cash_account_id)
      expect(balance_history[0].effective_from.strftime('%c')).to eql(effective_from.utc.strftime('%c'))
      expect(balance_history[0].effective_till).to eql(deleted_time)
      expect(balance_history[0]).to be_valid_now
    end

    it "reports error when there is no effective record found" do
      balance = balance_klass.create(amount: amount, cash_account_id: cash_account_id,
                 effective_from: effective_from, effective_till: effective_till)
      expect(balance.reload.delete(effective_till: deleted_time)).to be_falsy

      balance_history = balance_klass.history(cash_account_id)
      expect(balance_history.count).to eql(1)

      expect(balance_history[0].amount).to eql(amount)
      expect(balance_history[0].cash_account_id).to eql(cash_account_id)
      expect(balance_history[0].effective_from).to be_present
      expect(balance_history[0].effective_till.strftime('%c')).to eql(effective_till.utc.strftime('%c'))
      expect(balance_history[0]).to be_valid_now
    end
  end

  describe "#delete!" do
    let(:deleted_time) { Time.now.round }

    it "makes current effective record ineffective" do
      balance = balance_klass.create(amount: amount, cash_account_id: cash_account_id,
                 effective_from: effective_from)
      balance.delete!(effective_till: deleted_time)

      balance_history = balance_klass.history(cash_account_id)
      expect(balance_history.count).to eql(1)

      expect(balance_history[0].amount).to eql(amount)
      expect(balance_history[0].cash_account_id).to eql(cash_account_id)
      expect(balance_history[0].effective_from.strftime('%c')).to eql(effective_from.utc.strftime('%c'))
      expect(balance_history[0].effective_till).to eql(deleted_time)
      expect(balance_history[0]).to be_valid_now
    end

    it "reports error when there is no effective record found" do
      balance = balance_klass.create(amount: amount, cash_account_id: cash_account_id,
                 effective_from: effective_from, effective_till: effective_till)
      expect{balance.reload.delete!(effective_till: deleted_time)}.to raise_error('no effective record found')
    end
  end

  describe "#destroy!" do
    let(:deleted_time) { Time.now.round }

    it "makes current effective record ineffective" do
      balance = balance_klass.create(amount: amount, cash_account_id: cash_account_id,
                 effective_from: effective_from)
      balance.destroy!(effective_till: deleted_time)

      balance_history = balance_klass.history(cash_account_id)
      expect(balance_history.count).to eql(1)

      expect(balance_history[0].amount).to eql(amount)
      expect(balance_history[0].cash_account_id).to eql(cash_account_id)
      expect(balance_history[0].effective_from.strftime('%c')).to eql(effective_from.utc.strftime('%c'))
      expect(balance_history[0].effective_till).to eql(deleted_time)
      expect(balance_history[0]).to be_valid_now
    end

    it "reports error when there is no effective record found" do
      balance = balance_klass.create(amount: amount, cash_account_id: cash_account_id,
                 effective_from: effective_from, effective_till: effective_till)
      expect{balance.reload.destroy!(effective_till: deleted_time)}.to raise_error('no effective record found')
    end
  end

  describe "#destroy" do
    let(:deleted_time) { Time.now.round }

    it "makes current effective record ineffective" do
      balance = balance_klass.create(amount: amount, cash_account_id: cash_account_id,
                 effective_from: effective_from)
      balance.destroy(effective_till: deleted_time)

      balance_history = balance_klass.history(cash_account_id)
      expect(balance_history.count).to eql(1)

      expect(balance_history[0].amount).to eql(amount)
      expect(balance_history[0].cash_account_id).to eql(cash_account_id)
      expect(balance_history[0].effective_from.strftime('%c')).to eql(effective_from.utc.strftime('%c'))
      expect(balance_history[0].effective_till).to eql(deleted_time)
      expect(balance_history[0]).to be_valid_now
    end

    it "reports error when there is no effective record found" do
      balance = balance_klass.create(amount: amount, cash_account_id: cash_account_id,
                 effective_from: effective_from, effective_till: effective_till)
      expect(balance.reload.destroy(effective_till: deleted_time)).to be_falsy

      balance_history = balance_klass.history(cash_account_id)
      expect(balance_history.count).to eql(1)
    end
  end
end
