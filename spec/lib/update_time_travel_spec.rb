require 'rails_helper'

describe TimeTravel do
  before(:all) do
    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
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
        [:cash_account_id]
      end
    end
  end

  let(:sep_2) { Date.parse('02/09/2018').beginning_of_day }
  let(:sep_5) { Date.parse('05/09/2018').beginning_of_day }
  let(:sep_8) { Date.parse('08/09/2018').beginning_of_day }
  let(:sep_10) { Date.parse('10/09/2018').beginning_of_day }
  let(:sep_15) { Date.parse('15/09/2018').beginning_of_day }
  let(:sep_18) { Date.parse('18/09/2018').beginning_of_day }
  let(:sep_19) { Date.parse('19/09/2018').beginning_of_day }
  let(:sep_20) { Date.parse('20/09/2018').beginning_of_day }
  let(:sep_21) { Date.parse('21/09/2018').beginning_of_day }
  let(:sep_25) { Date.parse('25/09/2018').beginning_of_day }
  let(:infinite_date) { Date.parse('01/01/2040').beginning_of_day}

  let(:cash_account_id) { 1 }
  let(:amount) { 50 }
  let(:current_time) {Time.current}
  let(:cash_account_id_for_definite_effectiveness) { 2 }

  let!(:balance) { balance_klass.create(amount: amount, cash_account_id: cash_account_id,
    effective_from: sep_20)}
  let!(:balance_definiteEffective) { balance_klass.create(amount: amount, cash_account_id: cash_account_id_for_definite_effectiveness,
    effective_from: sep_20, effective_till: sep_25)}

  describe "validations" do
    context "update!" do
      it "raises error when effective_from is greater than effective_till" do
        expect{
          balance.update!(amount: 10, effective_from: sep_10, effective_till: sep_2)
        }.to raise_error("Validation failed: effective_from can't be greater than effective_till")
        expect(balance.errors.full_messages).to include("effective_from can't be greater than effective_till")
      end

      it "raises error when passed identifier that has no exiting history" do
        expect{
          balance.update!(cash_account_id: 3, amount: 10, effective_from: sep_21)
        }.to raise_error("Validation failed: does not have history")
        expect(balance.errors.full_messages).to include("does not have history")

        history = balance_klass.history(cash_account_id)
        expect(history.count).to eql(1)
      end

      it "raises no error when passed identifier that has exiting history" do
        expect{
          balance.update!(cash_account_id: 1, amount: 10, effective_from: sep_21)
        }.not_to raise_error
        history = balance_klass.history(cash_account_id)
        expect(history.count).to eql(2)
      end

      it "returns true and does not Update when no Attributes passed to Update other than effective_from" do
        expect(
          balance.update(effective_from: sep_21)
        ).to be_truthy

        history = balance_klass.history(cash_account_id)
        expect(history.count).to eql(1)
      end
    end

    context "update" do
      it "returns false when effective_from is greater than effective_till" do
        expect(
          balance.update(amount: 10, effective_from: sep_10, effective_till: sep_2)
        ).to be_falsy
        expect(balance.errors.full_messages).to include("effective_from can't be greater than effective_till")
      end
    end
  end

  describe "update! single historic trail" do
    #  date: 20 -- infi
    # value:    50
    # ------------update--------------
    #  date: 20 -- CT -- infi
    # value:    50    10
    it "with effective_from defaulted to current time and effective_till defaulted to infinity" do
      balance.update!(amount: 10)
      expect(balance_klass.count).to eql(4)
      expect(balance_klass.historically_valid.count).to eql(3)

      history = balance.history()
      expect(history.count).to eql(2)

      expect(history[0].amount).to eql(50)
      expect(history[0].effective_from).to eql(sep_20)
      expect(history[0].effective_till).to be_present
      expect(history[0].valid_from).to eql(history[0].effective_till)

      expect(history[1].amount).to eql(10)
      expect(history[1].effective_from).to eql(history[0].effective_till)
      expect(history[1]).to be_effective_now
      expect(history[1].valid_from).to eql(history[0].effective_till)
    end

    #  date: 20 -- infi
    # value:    50
    # ------------update--------------
    #  date: 20 -- 21 -- infi
    # value:    50    10
    it "with effective_from set to date after existing history" do
      new_effective_from = Date.parse('21/09/2018').beginning_of_day
      balance.update!(amount: 10, effective_from: new_effective_from)

      history = balance.history()
      expect(history.count).to eql(2)

      expect(history.first.amount).to eql(50)
      expect(history.first.effective_from).to eql(sep_20)
      expect(history.first.effective_till).to eql(sep_21)
      expect(history.first.valid_from).to be_present

      expect(history.last.amount).to eql(10)
      expect(history.last.effective_from).to eql(sep_21)
      expect(history.last).to be_effective_now
      expect(history.last.valid_from).to be_present
    end

    #  date: 20 -- infi
    # value:    50
    # ------------update--------------
    #  date: 19 -- 20 -- infi
    # value:    10    50
    it "with effective_from set before existing history" do
      balance.update!(amount: 10, effective_from: sep_19, effective_till: sep_20)

      history = balance.history()
      expect(history.count).to eql(2)

      expect(history.first.amount).to eql(10)
      expect(history.first.effective_from).to eql(sep_19)
      expect(history.first.effective_till).to eql(sep_20)
      expect(history.first.valid_from).to be_present

      expect(history.last.amount).to eql(50)
      expect(history.last.effective_from).to eql(sep_20)
      expect(history.last).to be_effective_now
      expect(history.last.valid_from).to be_present
    end

    #  date: 20 -- infi
    # value:    50
    # ------------update(10, e.f:18Sep , e.t:25Sep)--------------
    #  date: 18 -- 25 -- infi
    # value:    10    50
    it "with effective_from set to date before existng history and effective_till set to date after existing history" do
      balance.update!(amount: 10, effective_from: sep_18, effective_till: sep_25)

      history = balance_klass.history(cash_account_id)
      expect(history.count).to eql(2)

      expect(history.first.amount).to eql(10)
      expect(history.first.effective_from).to eql(sep_18)
      expect(history.first.effective_till).to eql(sep_25)
      expect(history.first.valid_from).to be_present

      expect(history.last.amount).to eql(50)
      expect(history.last.effective_from).to eql(sep_25)
      expect(history.last).to be_effective_now
      expect(history.last.valid_from).to be_present
    end

    #  date: 20 -- infi
    # value:    50
    # ------------update(10,e.f:sep15,e.t:sep18)--------------
    #  date: 15 -- 19 20 -- infi
    # value:    10       50
    it "with effective_from set before existing history with gap in timeline" do
      balance.update!(amount: 10, effective_from: sep_15, effective_till: sep_19)

      history = balance_klass.history(cash_account_id)
      expect(history.count).to eql(2)

      expect(history.first.amount).to eql(10)
      expect(history.first.effective_from).to eql(sep_15)
      expect(history.first.effective_till).to eql(sep_19)
      expect(history.first.valid_from).to be_present

      expect(history.last.amount).to eql(50)
      expect(history.last.effective_from).to eql(sep_20)
      expect(history.last).to be_effective_now
      expect(history.last.valid_from).to be_present
    end

    #  date: 20 -- infi
    # value:    50
    # ------------update(10,e.f:sep20)--------------
    #  date: 20 -- infi
    # value:    10
    it "with effective_from equal to the existing history " do
      balance.update!(amount: 10, effective_from: sep_20)

      history = balance_klass.history(cash_account_id)
      expect(history.count).to eql(1)

      expect(history.first.amount).to eql(10)
      expect(history.first.effective_from).to eql(sep_20)
      expect(history.first.effective_till).to be_present
      expect(history.first.valid_from).to be_present
    end
  end

  describe "#update! 2 historic trails" do
    before do
      balance.update!(amount: 10, effective_from: sep_10, effective_till: sep_20)
    end

    #  date: 10 -- 20 -- infi
    # value:    10    50
    # ------------update--------------
    #  date: 10 -- 20 -- 25 -- infi
    # value:    10    50    25
    it "with effective_from is set to date after existing history" do
      balance.update!(amount: 25, effective_from: sep_25)

      history = balance.history()
      expect(history.count).to eql(3)

      expect(history[0].effective_from).to eql(sep_10)
      expect(history[0].effective_till).to eql(sep_20)
      expect(history[0].amount).to eql(10)

      expect(history[1].effective_from).to eql(sep_20)
      expect(history[1].effective_till).to eql(sep_25)
      expect(history[1].amount).to eql(50)

      expect(history[2].effective_from).to eql(sep_25)
      expect(history[2]).to be_effective_now
      expect(history[2].amount).to eql(25)
    end

    #  date: 10 -- 20 -- infi
    # value:    10    50
    # ------------update--------------
    #  date: 05 -- infi
    # value:    31
    it "with effective_from set to date before existing history" do
      balance.update!(amount: 31, effective_from: sep_5)

      history = balance.history()
      expect(history.count).to eql(1)

      expect(history[0].effective_from).to eql(sep_5)
      expect(history[0]).to be_effective_now
      expect(history[0].amount).to eql(31)
    end

    #  date: 10 -- 20 -- infi
    # value:    10    50
    # ------------update--------------
    #  date: 10 -- 15 -- 25 -- infi
    # value:    10    25    50
    it "with effective_from set to date in historical records and effective_till set to after existing history" do
      balance.update!(amount: 25, effective_from: sep_15, effective_till: sep_25)

      history = balance.history()
      expect(history.count).to eql(3)

      expect(history[0].effective_from).to eql(sep_10)
      expect(history[0].effective_till).to eql(sep_15)
      expect(history[0].amount).to eql(10)

      expect(history[1].effective_from).to eql(sep_15)
      expect(history[1].effective_till).to eql(sep_25)
      expect(history[1].amount).to eql(25)

      expect(history[2].effective_from).to eql(sep_25)
      expect(history[2]).to be_effective_now
      expect(history[2].amount).to eql(50)
    end

    #  date: 10 -- 20 -- infi
    # value:    10    50
    # ------------update--------------
    #  date: 10 -- 15 -- 20 -- infi
    # value:    10    25    50
    it "with effective_from & effective_from set to date in historical records" do
      balance.update!(amount: 25, effective_from: sep_15, effective_till: sep_20)

      history = balance.history()
      expect(history.count).to eql(3)

      expect(history[0].effective_from).to eql(sep_10)
      expect(history[0].effective_till).to eql(sep_15)
      expect(history[0].amount).to eql(10)

      expect(history[1].effective_from).to eql(sep_15)
      expect(history[1].effective_till).to eql(sep_20)
      expect(history[1].amount).to eql(25)

      expect(history[2].effective_from).to eql(sep_20)
      expect(history[2]).to be_effective_now
      expect(history[2].amount).to eql(50)
    end

    #  date: 10 -- 20 -- infi
    # value:    10    50
    # ------------update(25,e.f:15Sep, e.t:18Sep)--------------
    #  date: 10 -- 15 -- 18 -- 20 -- infi
    # value:    10    25    10    50
    it "with effective_from & effective_till set to date that is inbetween one of the historical records effective range" do
     balance.update!(amount: 25, effective_from: sep_15, effective_till: sep_18)

     history = balance_klass.history(cash_account_id)
     expect(history.count).to eql(4)

     expect(history[0].effective_from).to eql(sep_10)
     expect(history[0].effective_till).to eql(sep_15)
     expect(history[0].amount).to eql(10)

     expect(history[1].effective_from).to eql(sep_15)
     expect(history[1].effective_till).to eql(sep_18)
     expect(history[1].amount).to eql(25)

     expect(history[2].effective_from).to eql(sep_18)
     expect(history[2].effective_till).to eql(sep_20)
     expect(history[2].amount).to eql(10)

     expect(history[3].effective_from).to eql(sep_20)
     expect(history[3]).to be_effective_now
     expect(history[3].amount).to eql(50)
    end
  end

  describe "#update! with 3 historic trails" do
    before do
      balance.update!(amount: 10, effective_from: sep_10, effective_till: sep_20)
      balance.update!(amount: 9, effective_from: sep_5, effective_till: sep_10)
    end

    #  date: 05 -- 10 -- 20 -- infi
    # value:    09    10    50
    # ------------update--------------
    #  date: 05 -- 10 -- 20 -- 25 -- infi
    # value:    09    10    50    25
    it "with effective_from set to date after existing history" do
      balance.update!(amount: 25, effective_from: sep_25)

      history = balance.history()
      expect(history.count).to eql(4)

      expect(history[0].effective_from).to eql(sep_5)
      expect(history[0].effective_till).to eql(sep_10)
      expect(history[0].amount).to eql(9)

      expect(history[1].effective_from).to eql(sep_10)
      expect(history[1].effective_till).to eql(sep_20)
      expect(history[1].amount).to eql(10)

      expect(history[2].effective_from).to eql(sep_20)
      expect(history[2].effective_till).to eql(sep_25)
      expect(history[2].amount).to eql(50)

      expect(history[3].effective_from).to eql(sep_25)
      expect(history[3]).to be_effective_now
      expect(history[3].amount).to eql(25)
    end

    #  date: 05 -- 10 -- 20 -- infi
    # value:    09    10    50
    # ------------update--------------
    #  date: 02 -- 05 -- 10 -- 20 -- infi
    # value:    05    09    10    50
    it "with effective_from set to date before history and effective till to start of history" do
      balance.update!(amount: 05, effective_from: sep_2, effective_till: sep_5)

      history = balance.history()
      expect(history.count).to eql(4)

      expect(history[0].effective_from).to eql(sep_2)
      expect(history[0].effective_till).to eql(sep_5)
      expect(history[0].amount).to eql(5)

      expect(history[1].effective_from).to eql(sep_5)
      expect(history[1].effective_till).to eql(sep_10)
      expect(history[1].amount).to eql(9)

      expect(history[2].effective_from).to eql(sep_10)
      expect(history[2].effective_till).to eql(sep_20)
      expect(history[2].amount).to eql(10)

      expect(history[3].effective_from).to eql(sep_20)
      expect(history[3]).to be_effective_now
      expect(history[3].amount).to eql(50)
    end

    #  date: 05 -- 10 -- 20 -- infi
    # value:    09    10    50
    # ------------update--------------
    #  date: 02 -- infi
    # value:    80
    it "with effective_from set to date before history" do
      balance.update!(amount: 80, effective_from: sep_2)

      history = balance.history()
      expect(history.count).to eql(1)

      expect(history[0].effective_from).to eql(sep_2)
      expect(history[0]).to be_effective_now
      expect(history[0].amount).to eql(80)
    end

    #  date: 05 -- 10 -- 20 -- infi
    # value:    09    10    50
    # ------------update(25,e.f:2sep, e.t:15Sep)--------------
    #  date: 02 -- 15 -- 20 -- inf
    # value:    25    10    50
    it "with effective_from set to date before history and effective_till splits one of the historical record effective date range" do
      balance.update!(amount: 25, effective_from: sep_2, effective_till: sep_15)

      history = balance_klass.history(cash_account_id)
      expect(history.count).to eql(3)

      expect(history[0].effective_from).to eql(sep_2)
      expect(history[0].effective_till).to eql(sep_15)
      expect(history[0].amount).to eql(25)

      expect(history[1].effective_from).to eql(sep_15)
      expect(history[1].effective_till).to eql(sep_20)
      expect(history[1].amount).to eql(10)

      expect(history[2].effective_from).to eql(sep_20)
      expect(history[2]).to be_effective_now
      expect(history[2].amount).to eql(50)
    end

    #  date: 05 -- 10 -- 20 -- infi
    # value:    09    10    50
    # ------------update(25,e.f:8sep, e.t:15Sep)--------------
    #  date: 05 -- 08 -- 15 -- 20 -- inf
    # value:    09    25    10    50
    it "with effective_from splits one of the historical record and effective_till splits another  historical record effective date range" do
      balance.update!(amount: 25, effective_from: sep_8, effective_till: sep_15)

      history = balance_klass.history(cash_account_id)
      expect(history.count).to eql(4)

      expect(history[0].effective_from).to eql(sep_5)
      expect(history[0].effective_till).to eql(sep_8)
      expect(history[0].amount).to eql(9)

      expect(history[1].effective_from).to eql(sep_8)
      expect(history[1].effective_till).to eql(sep_15)
      expect(history[1].amount).to eql(25)

      expect(history[2].effective_from).to eql(sep_15)
      expect(history[2].effective_till).to eql(sep_20)
      expect(history[2].amount).to eql(10)

      expect(history[3].effective_from).to eql(sep_20)
      expect(history[3]).to be_effective_now
      expect(history[3].amount).to eql(50)
    end
  end

  describe "update!" do
    context "on definite effectiveness of history " do
      #  date: 20 -- 25
      # value:    50
      # ------------update(10)--------------
      #  date: 20 -- 25 : CT -- infi
      # value:    50         10
      it " with no effective_from or effective_till attributes where currentTime is greater than effective history" do
        balance_definiteEffective.update!(amount:10)
        expect(balance_klass.count).to eql(3)
        expect(balance_klass.historically_valid.count).to eql(3)

        history = balance_klass.history(cash_account_id_for_definite_effectiveness)
        expect(history.count).to eql(2), "Expected to create new record for Update with the given data"

        expect(history.first.effective_from).to eql(sep_20)
        expect(history.first.effective_till).to eql(sep_25)
        expect(history.first.amount).to eql(50)

        expect(history.last.amount).to eql(10)
        expect(history.last.effective_from.to_time.to_i).to eql(current_time.to_time.to_i)
        expect(history.last.effective_till).to eql(infinite_date)
        expect(history.last.valid_from.to_time.to_i).to eql(current_time.to_time.to_i)
        expect(history.last).to be_effective_now
      end

      #  date: 20 -- 25
      # value:    50
      # ------------update(10,e.f:15-Sep)--------------
      #  date: 18 -- infi
      # value:    10
      it " with effective_from set to date lesser than effective history" do
        balance_definiteEffective.update!(amount:10, effective_from: sep_15)
        expect(balance_klass.count).to eql(3)
        expect(balance_klass.historically_valid.count).to eql(2)

        history = balance_klass.history(cash_account_id_for_definite_effectiveness)
        expect(history.count).to eql(1)

        expect(history.last.amount).to eql(10)
        expect(history.last.effective_from).to eql(sep_15)
        expect(history.last.effective_till).to eql(infinite_date)
        time_diff = ((history.last.valid_from.to_time.to_i - current_time.to_time.to_i).abs < 3)
        expect(time_diff).to be_truthy # added diff validation as execution time is affecting current time
        expect(history.last).to be_effective_now
      end

      #  date: 15 -- 19 : 20 -- 25
      # value:    15         50
      # ------------update(10,e.f:18-Sep,e.t:sep_21)--------------
      #  date: 15 -- 18 -- 21 -- 25
      # value:    15    10    50
      it " with effective from and Till date range is between existing history effective range" do
        balance_definiteEffective.update!(amount:15, effective_from:sep_15, effective_till:sep_19)
        balance_definiteEffective.update!(amount:10, effective_from: sep_18 , effective_till:sep_21)
        expect(balance_klass.count).to eql(6)
        expect(balance_klass.historically_valid.count).to eql(4)

        history = balance_klass.history(cash_account_id_for_definite_effectiveness)
        expect(history.count).to eql(3)

        expect(history[0].amount).to eql(15)
        expect(history[0].effective_from).to eql(sep_15)
        expect(history[0].effective_till).to eql(sep_18)
        valid_from_verification = (history[0].valid_from.to_time.to_i - current_time.to_time.to_i).abs < 5
        expect(valid_from_verification).to be_truthy
        expect(history[0].valid_till).to eql(infinite_date)

        expect(history[1].amount).to eql(10)
        expect(history[1].effective_from).to eql(sep_18)
        expect(history[1].effective_till).to eql(sep_21)
        expect(history[1].valid_from.to_time.to_i).to eql(current_time.to_time.to_i)
        expect(history[1].valid_till).to eql(infinite_date)

        expect(history[2].amount).to eql(50)
        expect(history[2].effective_from).to eql(sep_21)
        expect(history[2].effective_till).to eql(sep_25)
        expect(history[2].valid_from.to_time.to_i).to eql(current_time.to_time.to_i)
        expect(history[2].valid_till).to eql(infinite_date)
      end
    end
  end

  describe "update" do
    before do
      balance.update!(amount: 10, effective_from: sep_10, effective_till: sep_20)
    end

    #  date: 10 -- 20 -- infi
    # value:    10    50
    # ------------update--------------
    #  date: 10 -- 15 -- 25 -- infi
    # value:    10    25    50
    it "with effective_from set to date in historical records and effective_till set to after existing history" do
      expect(balance.update(amount: 25, effective_from: sep_15, effective_till: sep_25)).to be_truthy

      history = balance.history()
      expect(history.count).to eql(3)

      expect(history[0].effective_from).to eql(sep_10)
      expect(history[0].effective_till).to eql(sep_15)
      expect(history[0].amount).to eql(10)

      expect(history[1].effective_from).to eql(sep_15)
      expect(history[1].effective_till).to eql(sep_25)
      expect(history[1].amount).to eql(25)

      expect(history[2].effective_from).to eql(sep_25)
      expect(history[2]).to be_effective_now
      expect(history[2].amount).to eql(50)
    end
  end

  describe "save!" do
    before do
      balance.update!(amount: 10, effective_from: sep_10, effective_till: sep_20)
    end

    #  date: 10 -- 20 -- infi
    # value:    10    50
    # ------------update--------------
    #  date: 10 -- 15 -- 25 -- infi
    # value:    10    25    50
    it "with effective_from set to date in historical records and effective_till set to after existing history" do
      balance.amount = 25
      balance.effective_from = sep_15
      balance.effective_till = sep_25

      expect(balance.save!).to be_truthy

      history = balance.history()
      expect(history.count).to eql(3)

      expect(history[0].effective_from).to eql(sep_10)
      expect(history[0].effective_till).to eql(sep_15)
      expect(history[0].amount).to eql(10)

      expect(history[1].effective_from).to eql(sep_15)
      expect(history[1].effective_till).to eql(sep_25)
      expect(history[1].amount).to eql(25)

      expect(history[2].effective_from).to eql(sep_25)
      expect(history[2]).to be_effective_now
      expect(history[2].amount).to eql(50)
    end
  end
end
