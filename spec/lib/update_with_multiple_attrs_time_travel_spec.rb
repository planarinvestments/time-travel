require 'rails_helper'
require "pp"

describe TimeTravel do
  let(:balance_klass) do
    Class.new(ActiveRecord::Base) do
      self.table_name = 'balances_multiple_attrs'
      include TimeTravel::TimelineHelper

      def self.timeline_fields
        [:cash_account_id]
      end

      def self.batch_size
        1000
      end
    end
  end

  let(:sep_2) { Date.parse('02/09/2018').beginning_of_day }
  let(:sep_5) { Date.parse('05/09/2018').beginning_of_day }
  let(:sep_8) { Date.parse('08/09/2018').beginning_of_day }
  let(:sep_10) { Date.parse('10/09/2018').beginning_of_day }
  let(:sep_15) { Date.parse('15/09/2018').beginning_of_day }
  let(:sep_19) { Date.parse('19/09/2018').beginning_of_day }
  let(:sep_20) { Date.parse('20/09/2018').beginning_of_day }
  let(:sep_21) { Date.parse('21/09/2018').beginning_of_day }
  let(:sep_23) { Date.parse('23/09/2018').beginning_of_day }
  let(:sep_25) { Date.parse('25/09/2018').beginning_of_day }
  let(:sep_28) { Date.parse('28/09/2018').beginning_of_day }
  let(:sep_30) { Date.parse('30/09/2018').beginning_of_day }
  let(:infinite_date) { balance_klass::INFINITE_DATE }

  let(:cash_account_id) { 1 }
  let(:amount) { 50 }
  let(:current_time) { Time.current }
  let(:cash_account_id_for_definite_effectiveness) { 2 }

  let!(:balance) { balance_klass.create(amount: amount, currency: "US", interest: 1, cash_account_id: cash_account_id,
    effective_from: sep_20)}
  let!(:balance_definiteEffective) { balance_klass.create(amount: amount, currency: "US", interest: 1, cash_account_id: cash_account_id_for_definite_effectiveness,
    effective_from: sep_20, effective_till: sep_25)}

  let(:timeline) {
    balance_klass.timeline(cash_account_id: cash_account_id)
  }

  let(:terminated_timeline) {
    balance_klass.timeline(cash_account_id: cash_account_id_for_definite_effectiveness)
  }

  describe "update! multiple attributes 3 historic trails" do
    before do
      timeline.create_or_update({amount: 9, currency: "IN", interest: 3}, effective_from: sep_5, effective_till: sep_10)
      timeline.create_or_update({amount: 10, currency: "SG", interest: 2}, effective_from: sep_10, effective_till: sep_20)
    end

    context "when one argument passed for update " do
      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_25)--------------
      #     date: 05 -- 10 -- 20 -- 25 -- infi
      #    value:    09    10    50    25
      # currency:    IN    SG    US    US
      # interest:     3     2     1     1
      it "with effective_from set to date in future of history" do
        timeline.update({amount: 25}, effective_from: sep_25)
        expect(balance_klass.count).to eql(6)
        expect(balance_klass.historically_valid.count).to eql(5)

        history = timeline.effective_history
        expect(history.count).to eql(4)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_20)
        expect(history[1].amount).to eql(10)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_20)
        expect(history[2].effective_till).to eql(sep_25)
        expect(history[2].amount).to eql(50)
        expect(history[2].currency).to eql("US")
        expect(history[2].interest).to eql(1)

        expect(history[3].effective_from).to eql(sep_25)
        expect(history[3].effective_till).to eql(infinite_date)
        expect(history[3].valid_from.to_time).to be_between(current_time.to_time - 5.seconds, current_time.to_time + 5.seconds )
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to eql("US")
        expect(history[3].interest).to eql(1)

        history_invalid = balance_klass.where(cash_account_id: 1).where.not(valid_till: infinite_date)
        expect(history_invalid.count).to eql(1)

        expect(history_invalid[0].effective_from).to eql(sep_20)
        expect(history_invalid[0].effective_till).to eql(infinite_date)
        expect(history_invalid[0].amount).to eql(50)
        expect(history_invalid[0].currency).to eql("US")
        expect(history_invalid[0].interest).to eql(1)
        expect(history_invalid[0].valid_till.to_time).to be_between(current_time.to_time - 5.seconds, current_time.to_time + 5.seconds )
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_10)--------------
      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    25    25
      # currency:    IN    SG    US
      # interest:     3     2     1
      it "with effective_from set to date in middle of history and does not split any existing record" do
        timeline.update({amount: 25}, effective_from: sep_10)
        history = timeline.effective_history
        expect(balance_klass.count).to eql(6)
        expect(balance_klass.historically_valid.count).to eql(4)
        expect(history.count).to eql(3)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_20)
        expect(history[1].amount).to eql(25)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_20)
        expect(history[2].effective_till).to eql(infinite_date)
        expect(history[2].amount).to eql(25)
        expect(history[2].currency).to eql("US")
        expect(history[2].interest).to eql(1)
        expect(history[2]).to be_effective_now

        history_invalid = balance_klass.where(cash_account_id: 1).where.not(valid_till: infinite_date).order("effective_from ASC")
        expect(history_invalid.count).to eql(2)
        expect(history_invalid[0].effective_from).to eql(sep_10)
        expect(history_invalid[0].effective_till).to eql(sep_20)
        expect(history_invalid[0].amount).to eql(10)
        expect(history_invalid[0].currency).to eql("SG")
        expect(history_invalid[0].interest).to eql(2)
        expect(history_invalid[0].valid_till.to_time).to be_between(current_time.to_time - 5.seconds, current_time.to_time + 5.seconds )

        expect(history_invalid[1].effective_from).to eql(sep_20)
        expect(history_invalid[1].effective_till).to eql(infinite_date)
        expect(history_invalid[1].amount).to eql(50)
        expect(history_invalid[1].currency).to eql("US")
        expect(history_invalid[1].interest).to eql(1)
        expect(history_invalid[1].valid_till.to_time).to be_between(current_time.to_time - 5.seconds, current_time.to_time + 5.seconds )
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_15)--------------
      #     date: 05 -- 10 -- 15 -- 20 -- infi
      #    value:    09    10    25    25
      # currency:    IN    SG    SG    US
      # interest:     3     2     2     1
      it "with effective_from set to date in middle of history and split any existing record" do
        timeline.update({amount: 25}, effective_from: sep_15)
        expect(balance_klass.count).to eql(7)
        expect(balance_klass.historically_valid.count).to eql(5)
        history = timeline.effective_history
        expect(history.count).to eql(4)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_15)
        expect(history[1].amount).to eql(10)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_15)
        expect(history[2].effective_till).to eql(sep_20)
        expect(history[2].amount).to eql(25)
        expect(history[2].currency).to eql("SG")
        expect(history[2].interest).to eql(2)

        expect(history[3].effective_from).to eql(sep_20)
        expect(history[3].effective_till).to eql(infinite_date)
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to eql("US")
        expect(history[3].interest).to eql(1)
        expect(history[3]).to be_effective_now
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_2)--------------
      #     date: 02 -- 05 -- 10 -- 20 -- infi
      #    value:    25    25    25    25
      # currency:    nil   IN    SG    US
      # interest:    nil    3     2     1
      it "with effective_from set to date lesser than of history" do
        timeline.update({amount: 25}, effective_from: sep_2)
        expect(balance_klass.count).to eql(8)
        expect(balance_klass.historically_valid.count).to eql(5)
        history = timeline.effective_history
        expect(history.count).to eql(4)

        expect(history[0].effective_from).to eql(sep_2)
        expect(history[0].effective_till).to eql(sep_5)
        expect(history[0].amount).to eql(25)
        expect(history[0].valid_from.to_time).to be_between(current_time.to_time - 5.seconds, current_time.to_time + 5.seconds )
        expect(history[0].currency).to be_nil
        expect(history[0].interest).to be_nil

        expect(history[1].effective_from).to eql(sep_5)
        expect(history[1].effective_till).to eql(sep_10)
        expect(history[1].amount).to eql(25)
        expect(history[1].currency).to eql("IN")
        expect(history[1].interest).to eql(3)

        expect(history[2].effective_from).to eql(sep_10)
        expect(history[2].effective_till).to eql(sep_20)
        expect(history[2].amount).to eql(25)
        expect(history[2].currency).to eql("SG")
        expect(history[2].interest).to eql(2)

        expect(history[3].effective_from).to eql(sep_20)
        expect(history[3].effective_till).to eql(infinite_date)
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to eql("US")
        expect(history[3].interest).to eql(1)
        expect(history[3]).to be_effective_now
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:    3     2     1
      # ------------update(amt:25, e.f:15, e.t: 25)--------------
      #     date: 05 -- 10 -- 15 -- 20 -- 25 -- infi
      #    value:    09    10    25    25    50
      # currency:    IN    SG    SG    US    US
      # interest:     3     2     2     1     1
      it "with effective_from set to date in middle of history and effective till greater than latest effective date" do
        timeline.update({amount: 25}, effective_from: sep_15, effective_till: sep_25)

        history = timeline.effective_history
        expect(history.count).to eql(5)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_15)
        expect(history[1].amount).to eql(10)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_15)
        expect(history[2].effective_till).to eql(sep_20)
        expect(history[2].amount).to eql(25)
        expect(history[2].currency).to eql("SG")
        expect(history[2].interest).to eql(2)

        expect(history[3].effective_from).to eql(sep_20)
        expect(history[3].effective_till).to eql(sep_25)
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to eql("US")
        expect(history[3].interest).to eql(1)

        expect(history[4].effective_from).to eql(sep_25)
        expect(history[4]).to be_effective_now
        expect(history[4].amount).to eql(50)
        expect(history[4].currency).to eql("US")
        expect(history[4].interest).to eql(1)
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:    3     2     1
      # ------------update(amt:25, e.f:10, e.t: 19)--------------
      #     date: 05 -- 10 -- 19 -- 20 -- infi
      #    value:    09    25    10    50
      # currency:    IN    SG    SG    US
      # interest:     3     2     2     1
      it "with effective_from set to date equal one of the existing record and effective till splits record's effective date range" do
        timeline.update({amount: 25}, effective_from: sep_10, effective_till: sep_19)

        history = timeline.effective_history
        expect(history.count).to eql(4)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_19)
        expect(history[1].amount).to eql(25)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_19)
        expect(history[2].effective_till).to eql(sep_20)
        expect(history[2].amount).to eql(10)
        expect(history[2].currency).to eql("SG")
        expect(history[2].interest).to eql(2)

        expect(history[3].effective_from).to eql(sep_20)
        expect(history[3]).to be_effective_now
        expect(history[3].amount).to eql(50)
        expect(history[3].currency).to eql("US")
        expect(history[3].interest).to eql(1)
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:    3     2     1
      # ------------update(amt:25, e.f:2, e.t: 25)--------------
      #     date: 02 -- 05 -- 10 -- 20 -- 25 -- infi
      #    value:    25    25    25    25    50
      # currency:    nil   IN    SG    US    US
      # interest:    nil    3     2     1     1
      it "with effective_from set to date less than existing record and effective till splits record's effective date range" do
        timeline.update({amount: 25}, effective_from: sep_2, effective_till: sep_25)

        expect(balance_klass.count).to eql(9)
        expect(balance_klass.historically_valid.count).to eql(6)
        history = timeline.effective_history
        expect(history.count).to eql(5)

        expect(history[0].effective_from).to eql(sep_2)
        expect(history[0].effective_till).to eql(sep_5)
        expect(history[0].amount).to eql(25)
        expect(history[0].currency).to be_nil
        expect(history[0].interest).to be_nil

        expect(history[1].effective_from).to eql(sep_5)
        expect(history[1].effective_till).to eql(sep_10)
        expect(history[1].amount).to eql(25)
        expect(history[1].currency).to eql("IN")
        expect(history[1].interest).to eql(3)

        expect(history[2].effective_from).to eql(sep_10)
        expect(history[2].effective_till).to eql(sep_20)
        expect(history[2].amount).to eql(25)
        expect(history[2].currency).to eql("SG")
        expect(history[2].interest).to eql(2)

        expect(history[3].effective_from).to eql(sep_20)
        expect(history[3].effective_till).to eql(sep_25)
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to eql("US")
        expect(history[3].interest).to eql(1)

        expect(history[4].effective_from).to eql(sep_25)
        expect(history[4]).to be_effective_now
        expect(history[4].amount).to eql(50)
        expect(history[4].currency).to eql("US")
        expect(history[4].interest).to eql(1)
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:    3     2     1
      # ------------update(amt:25, e.f:10, e.t: 20)--------------
      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    25    10
      # currency:    IN    SG    US
      # interest:     3     2     1
      it "with effective_from and effective_till set to date equal one of the existing record effective date range" do
        timeline.update({amount: 25}, effective_from: sep_10, effective_till: sep_20)
        expect(balance_klass.count).to eql(5)
        expect(balance_klass.historically_valid.count).to eql(4)
        history = timeline.effective_history
        expect(history.count).to eql(3)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_20)
        expect(history[1].amount).to eql(25)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_20)
        expect(history[2]).to be_effective_now
        expect(history[2].amount).to eql(50)
        expect(history[2].currency).to eql("US")
        expect(history[2].interest).to eql(1)

        history_invalid = balance_klass.where(cash_account_id: 1).where.not(valid_till: infinite_date)
        expect(history_invalid.count).to eql(1)

        expect(history_invalid[0].effective_from).to eql(sep_10)
        expect(history_invalid[0].effective_till).to eql(sep_20)
        expect(history_invalid[0].amount).to eql(10)
        expect(history_invalid[0].currency).to eql("SG")
        expect(history_invalid[0].interest).to eql(2)
        expect(history_invalid[0].valid_till.to_time).to be_between(current_time.to_time - 5.seconds, current_time.to_time + 5.seconds )
      end
    end

    context "when partial arguments passed for update " do
      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_10, Currency:US)--------------
      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    25    25
      # currency:    IN    US    US
      # interest:     3     2     1
      it "with effective_from set to date in middle of history and does not split any existing record" do
        timeline.update({amount: 25, currency: "US"}, effective_from: sep_10)
        expect(balance_klass.count).to eql(6)
        expect(balance_klass.historically_valid.count).to eql(4)
        history = timeline.effective_history
        expect(history.count).to eql(3)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_20)
        expect(history[1].amount).to eql(25)
        expect(history[1].currency).to eql("US")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_20)
        expect(history[2].effective_till).to eql(infinite_date)
        expect(history[2].amount).to eql(25)
        expect(history[2].currency).to eql("US")
        expect(history[2].interest).to eql(1)
        expect(history[2]).to be_effective_now
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_15, cur:US)--------------
      #     date: 05 -- 10 -- 15 -- 20 -- infi
      #    value:    09    10    25    25
      # currency:    IN    SG    US    US
      # interest:     3     2     2     1

      it "with effective_from set to date in middle of history and split any existing record" do
        Timeline.bulk_update(balance_klass, [amount: 25, effective_from: sep_15, currency: "US", cash_account_id: 1])
        expect(balance_klass.count).to eql(7)

        expect(balance_klass.historically_valid.count).to eql(5)
        history = timeline.effective_history
        expect(history.count).to eql(4)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_15)
        expect(history[1].amount).to eql(10)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_15)
        expect(history[2].effective_till).to eql(sep_20)
        expect(history[2].amount).to eql(25)
        expect(history[2].currency).to eql("US")
        expect(history[2].interest).to eql(2)

        expect(history[3].effective_from).to eql(sep_20)
        expect(history[3].effective_till).to eql(infinite_date)
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to eql("US")
        expect(history[3].interest).to eql(1)
        expect(history[3]).to be_effective_now
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_2,cur:US)--------------
      #     date: 02 -- 05 -- 10 -- 20 -- infi
      #    value:    25    25    25    25
      # currency:    US    US    US    US
      # interest:    nil    3     2     1
      it "with effective_from set to date lesser than of history" do
        timeline.update({amount: 25, currency: "US"}, effective_from: sep_2)
        expect(balance_klass.count).to eql(8)
        expect(balance_klass.historically_valid.count).to eql(5)
        history = timeline.effective_history
        expect(history.count).to eql(4)

        expect(history[0].effective_from).to eql(sep_2)
        expect(history[0].effective_till).to eql(sep_5)
        expect(history[0].amount).to eql(25)
        expect(history[0].valid_from.to_time).to be_between(current_time.to_time - 5.seconds, current_time.to_time + 5.seconds )
        expect(history[0].currency).to eql("US")
        expect(history[0].interest).to be_nil

        expect(history[1].effective_from).to eql(sep_5)
        expect(history[1].effective_till).to eql(sep_10)
        expect(history[1].amount).to eql(25)
        expect(history[1].currency).to eql("US")
        expect(history[1].interest).to eql(3)

        expect(history[2].effective_from).to eql(sep_10)
        expect(history[2].effective_till).to eql(sep_20)
        expect(history[2].amount).to eql(25)
        expect(history[2].currency).to eql("US")
        expect(history[2].interest).to eql(2)

        expect(history[3].effective_from).to eql(sep_20)
        expect(history[3].effective_till).to eql(infinite_date)
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to eql("US")
        expect(history[3].interest).to eql(1)
        expect(history[3]).to be_effective_now
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:    3     2     1
      # ------------update(amt:25, e.f:15, e.t: 25, currency:IN)--------------
      #     date: 05 -- 10 -- 15 -- 20 -- 25 -- infi
      #    value:    09    10    25    25    50
      # currency:    IN    SG    IN    IN    US
      # interest:     3     2     2     1     1
      it "with effective_from set to date in middle of history and effective till greater than latest effective date" do
        timeline.update({amount: 25, currency: "IN"}, effective_from: sep_15, effective_till: sep_25)

        history = timeline.effective_history
        expect(history.count).to eql(5)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_15)
        expect(history[1].amount).to eql(10)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_15)
        expect(history[2].effective_till).to eql(sep_20)
        expect(history[2].amount).to eql(25)
        expect(history[2].currency).to eql("IN")
        expect(history[2].interest).to eql(2)

        expect(history[3].effective_from).to eql(sep_20)
        expect(history[3].effective_till).to eql(sep_25)
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to eql("IN")
        expect(history[3].interest).to eql(1)

        expect(history[4].effective_from).to eql(sep_25)
        expect(history[4]).to be_effective_now
        expect(history[4].amount).to eql(50)
        expect(history[4].currency).to eql("US")
        expect(history[4].interest).to eql(1)
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:    3     2     1
      # ------------update(amt:25, e.f:2, e.t: 25, cur: US)--------------
      #     date: 02 -- 05 -- 10 -- 20 -- 25 -- infi
      #    value:    25    25    25    25    50
      # currency:    US    US    US    US    US
      # interest:    nil    3     2     1     1

      it "with effective_from set to date less than existing record and effective till splits record's effective date range" do
        timeline.update({amount: 25, currency: "US"}, effective_from: sep_2, effective_till: sep_25)

        expect(balance_klass.count).to eql(9)
        expect(balance_klass.historically_valid.count).to eql(6)
        history = timeline.effective_history
        expect(history.count).to eql(5)

        expect(history[0].effective_from).to eql(sep_2)
        expect(history[0].effective_till).to eql(sep_5)
        expect(history[0].amount).to eql(25)
        expect(history[0].currency).to eql("US")
        expect(history[0].interest).to be_nil

        expect(history[1].effective_from).to eql(sep_5)
        expect(history[1].effective_till).to eql(sep_10)
        expect(history[1].amount).to eql(25)
        expect(history[1].currency).to eql("US")
        expect(history[1].interest).to eql(3)

        expect(history[2].effective_from).to eql(sep_10)
        expect(history[2].effective_till).to eql(sep_20)
        expect(history[2].amount).to eql(25)
        expect(history[2].currency).to eql("US")
        expect(history[2].interest).to eql(2)

        expect(history[3].effective_from).to eql(sep_20)
        expect(history[3].effective_till).to eql(sep_25)
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to eql("US")
        expect(history[3].interest).to eql(1)

        expect(history[4].effective_from).to eql(sep_25)
        expect(history[4]).to be_effective_now
        expect(history[4].amount).to eql(50)
        expect(history[4].currency).to eql("US")
        expect(history[4].interest).to eql(1)
      end
    end

    context "when all the arguments passed for update and resultant records squezed " do
      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_10, Currency:US)--------------
      #     date: 05 -- 10 -- infi
      #    value:    09    25
      # currency:    IN    US
      # interest:     3    2.5
      it "with effective_from set to date in middle of history and does not split any existing record " do
        timeline.update({amount: 25, currency: "US", interest: 3}, effective_from: sep_10)
        expect(balance_klass.count).to eql(5)
        expect(balance_klass.historically_valid.count).to eql(3)
        history = timeline.effective_history
        expect(history.count).to eql(2)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(infinite_date)
        expect(history[1].amount).to eql(25)
        expect(history[1].currency).to eql("US")
        expect(history[1].interest).to eql(3)
        expect(history[1]).to be_effective_now
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_15, cur: US , interest: 3)--------------
      #     date: 05 -- 10 -- 15 -- infi
      #    value:    09    10    25
      # currency:    IN    SG    US
      # interest:     3     2     3
      it "with effective_from set to date in middle of history and split any existing record" do
        timeline.update({amount: 25, currency: "US", interest: 3}, effective_from: sep_15)
        expect(balance_klass.count).to eql(6)
        expect(balance_klass.historically_valid.count).to eql(4)
        history = timeline.effective_history
        expect(history.count).to eql(3)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_15)
        expect(history[1].amount).to eql(10)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_15)
        expect(history[2].effective_till).to eql(infinite_date)
        expect(history[2].amount).to eql(25)
        expect(history[2].currency).to eql("US")
        expect(history[2].interest).to eql(3)
        expect(history[2]).to be_effective_now
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_2,cur:US, int: 2)--------------
      #     date: 02 -- infi
      #    value:    25
      # currency:    US
      # interest:    2

      it "with effective_from set to date lesser than that of exiting history" do
        timeline.update({amount: 25, currency: "US", interest: 2}, effective_from: sep_2)
        expect(balance_klass.count).to eql(5)
        expect(balance_klass.historically_valid.count).to eql(2)
        history = timeline.effective_history
        expect(history.count).to eql(1)

        expect(history[0].effective_from).to eql(sep_2)
        expect(history[0].effective_till).to eql(infinite_date)
        expect(history[0].amount).to eql(25)
        expect(history[0].currency).to eql("US")
        expect(history[0].interest).to eql(2)
        expect(history[0]).to be_effective_now
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:    3     2     1
      # ------------update(amt:25, e.f:15, e.t: 25, currency:IN, int:3)--------------
      #     date: 05 -- 10 -- 15 -- 25 -- infi
      #    value:    09    10    25    50
      # currency:    IN    SG    IN    US
      # interest:     3     2     3     1
      it "with effective_from set to date in middle of history and effective till greater than latest effective date" do
        timeline.update({amount: 25,  currency: "IN", interest: 3}, effective_from: sep_15, effective_till: sep_25)

        history = timeline.effective_history
        expect(history.count).to eql(4)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_15)
        expect(history[1].amount).to eql(10)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_15)
        expect(history[2].effective_till).to eql(sep_25)
        expect(history[2].amount).to eql(25)
        expect(history[2].currency).to eql("IN")
        expect(history[2].interest).to eql(3)

        expect(history[3].effective_from).to eql(sep_25)
        expect(history[3]).to be_effective_now
        expect(history[3].amount).to eql(50)
        expect(history[3].currency).to eql("US")
        expect(history[3].interest).to eql(1)
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:    3     2     1
      # ------------update(amt:25, e.f:2, e.t: 25, cur: US)--------------
      #     date: 02 -- 25 -- infi
      #    value:    25    50
      # currency:    US    US
      # interest:    2      1

      it "with effective_from set to date less than existing record and effective till splits record's effective date range" do
        timeline.update({amount: 25,  currency: "US", interest: 2}, effective_from: sep_2, effective_till: sep_25)

        expect(balance_klass.count).to eql(6)
        expect(balance_klass.historically_valid.count).to eql(3)
        history = timeline.effective_history
        expect(history.count).to eql(2)

        expect(history[0].effective_from).to eql(sep_2)
        expect(history[0].effective_till).to eql(sep_25)
        expect(history[0].amount).to eql(25)
        expect(history[0].currency).to eql("US")
        expect(history[0].interest).to eql(2)

        expect(history[1].effective_from).to eql(sep_25)
        expect(history[1]).to be_effective_now
        expect(history[1].amount).to eql(50)
        expect(history[1].currency).to eql("US")
        expect(history[1].interest).to eql(1)
      end

      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:    3     2     1
      # ------------update(amt:50, e.f:10, e.t: 20, currency:US, int:1)--------------
      #     date: 05 -- 10 -- 20 -- infi
      #    value:    09    50    50
      # currency:    IN    US    US
      # interest:     3     1     1
      it "with effective_from and effective_till set to date equal one of the existing record effective date range and all atrributes equal to that of next date range and records not squezed" do
        timeline.update({amount: 50, currency: "US", interest: 1}, effective_from: sep_10, effective_till: sep_20)


        expect(balance_klass.count).to eql(5)
        expect(balance_klass.historically_valid.count).to eql(4)

        history = timeline.effective_history
        expect(history.count).to eql(3)
        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_20)
        expect(history[1].amount).to eql(50)
        expect(history[1].currency).to eql("US")
        expect(history[1].interest).to eql(1)

        expect(history[2].effective_from).to eql(sep_20)
        expect(history[2]).to be_effective_now
        expect(history[2].amount).to eql(50)
        expect(history[2].currency).to eql("US")
        expect(history[2].interest).to eql(1)

        history_invalid = balance_klass.where(cash_account_id: 1).where.not(valid_till: infinite_date)
        expect(history_invalid.count).to eql(1)

        expect(history_invalid[0].effective_from).to eql(sep_10)
        expect(history_invalid[0].effective_till).to eql(sep_20)
        expect(history_invalid[0].amount).to eql(10)
        expect(history_invalid[0].currency).to eql("SG")
        expect(history_invalid[0].interest).to eql(2)
        expect(history_invalid[0].valid_till.to_time).to be_between(current_time.to_time - 5.seconds, current_time.to_time + 5.seconds)
      end
    end
  end

  describe "update! multiple attributes on definite effective historic data" do
    before do
      terminated_timeline.update({amount: 9, currency: "IN",interest: 3}, effective_from: sep_5, effective_till: sep_10)
      terminated_timeline.update({amount: 10, currency: "SG",interest: 2}, effective_from: sep_10, effective_till: sep_20)
    end
    context "when only one argument passed for update" do
      #     date: 05 -- 10 -- 20 -- 25
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_25)--------------
      #     date: 05 -- 10 -- 20 -- 23 -- 25 -- infi
      #    value:    09    10    50    25    25
      # currency:    IN    SG    US    US    nil
      # interest:     3     2     1     1    nil
      it "with effective_from date given to split existing history and will make data infinite effective  " do 
        terminated_timeline.update({amount: 25}, effective_from: sep_23)
        expect(balance_klass.count).to eql(7)
        expect(balance_klass.historically_valid.count).to eql(6)
        history = terminated_timeline.effective_history
        expect(history.count).to eql(5)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_20)
        expect(history[1].amount).to eql(10)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_20)
        expect(history[2].effective_till).to eql(sep_23)
        expect(history[2].amount).to eql(50)
        expect(history[2].currency).to eql("US")
        expect(history[2].interest).to eql(1)

        expect(history[3].effective_from).to eql(sep_23)
        expect(history[3].effective_till).to eql(sep_25)
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to eql("US")
        expect(history[3].interest).to eql(1)

        expect(history[4].effective_from).to eql(sep_25)
        expect(history[4].effective_till).to eql(infinite_date)
        expect(history[4].amount).to eql(25)
        expect(history[4].currency).to be_nil
        expect(history[4].interest).to be_nil
        expect(history[4]).to be_effective_now
      end

      #     date: 05 -- 10 -- 20 -- 25
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_28, e.t:sep_30)--------------
      #     date: 05 -- 10 -- 20 -- 25:28 -- 30
      #    value:    09    10    50       25
      # currency:    IN    SG    US       nil
      # interest:     3     2     1       nil
      it "with effective_from and effective till in future date range" do
        terminated_timeline.update({amount: 25}, effective_from: sep_28, effective_till: sep_30)
        expect(balance_klass.count).to eql(5)
        expect(balance_klass.historically_valid.count).to eql(5)
        history = terminated_timeline.effective_history
        expect(history.count).to eql(4)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_20)
        expect(history[1].amount).to eql(10)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_20)
        expect(history[2].effective_till).to eql(sep_25)
        expect(history[2].amount).to eql(50)
        expect(history[2].currency).to eql("US")
        expect(history[2].interest).to eql(1)

        expect(history[3].effective_from).to eql(sep_28)
        expect(history[3].effective_till).to eql(sep_30)
        expect(history[3].valid_from.to_time).to be_between(current_time.to_time - 5.seconds, current_time.to_time + 5.seconds)
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to be_nil
        expect(history[3].interest).to be_nil
      end

      #     date: 05 -- 10 -- 20 -- 25
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_19, e.t:sep_23)--------------
      #     date: 05 -- 10 -- 18 -- 20 -- 23 -- 25
      #    value:    09    10    25    25    50
      # currency:    IN    SG    SG    US    US
      # interest:     3     2     2    1     1
      it "with effective_from set to date splitting one of the records' date range and effective_till set to date that splits another record date range" do
        terminated_timeline.update({amount: 25}, effective_from: sep_19, effective_till: sep_23)
        expect(balance_klass.count).to eql(8)
        expect(balance_klass.historically_valid.count).to eql(6)
        history = terminated_timeline.effective_history
        expect(history.count).to eql(5)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_19)
        expect(history[1].amount).to eql(10)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_19)
        expect(history[2].effective_till).to eql(sep_20)
        expect(history[2].amount).to eql(25)
        expect(history[2].currency).to eql("SG")
        expect(history[2].interest).to eql(2)

        expect(history[3].effective_from).to eql(sep_20)
        expect(history[3].effective_till).to eql(sep_23)
        expect(history[3].valid_from.to_time).to be_between(current_time.to_time - 5.seconds, current_time.to_time + 5.seconds )
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to eql("US")
        expect(history[3].interest).to eql(1)

        expect(history[4].effective_from).to eql(sep_23)
        expect(history[4].effective_till).to eql(sep_25)
        expect(history[4].valid_from.to_time).to be_between(current_time.to_time - 5.seconds, current_time.to_time + 5.seconds )
        expect(history[4].amount).to eql(50)
        expect(history[4].currency).to eql("US")
        expect(history[4].interest).to eql(1)
      end
    end

    context "when partial no. of arguments passed for update" do
      #     date: 05 -- 10 -- 20 -- 25
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_23,curr:IN)--------------
      #     date: 05 -- 10 -- 20 -- 23 -- 25 -- infi
      #    value:    09    10    50    25    25
      # currency:    IN    SG    US    IN    IN
      # interest:     3     2     1     1    nil
      it "with effective_from date given to split existing history will make data infinite effective  " do
        terminated_timeline.update({amount: 25, currency: "IN"}, effective_from: sep_23)
        expect(balance_klass.count).to eql(7)
        expect(balance_klass.historically_valid.count).to eql(6)
        history = terminated_timeline.effective_history
        expect(history.count).to eql(5)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_20)
        expect(history[1].amount).to eql(10)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_20)
        expect(history[2].effective_till).to eql(sep_23)
        expect(history[2].amount).to eql(50)
        expect(history[2].currency).to eql("US")
        expect(history[2].interest).to eql(1)

        expect(history[3].effective_from).to eql(sep_23)
        expect(history[3].effective_till).to eql(sep_25)
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to eql("IN")
        expect(history[3].interest).to eql(1)

        expect(history[4].effective_from).to eql(sep_25)
        expect(history[4].effective_till).to eql(infinite_date)
        expect(history[4].amount).to eql(25)
        expect(history[4].currency).to eql("IN")
        expect(history[4].interest).to be_nil
        expect(history[4]).to be_effective_now
      end
    end


    context "when all the arguments being passed for update" do
      #     date: 05 -- 10 -- 20 -- 25
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_23,curr:IN, int:3)--------------
      #     date: 05 -- 10 -- 20 -- 23 -- infi
      #    value:    09    10    50    25
      # currency:    IN    SG    US    IN
      # interest:     3     2     1     3
      it "with effective_from date given to split existing history will make data infinite effective  " do

        terminated_timeline.update({amount: 25, currency: "IN", interest: "3"}, effective_from: sep_23)
        expect(balance_klass.count).to eql(6)
        expect(balance_klass.historically_valid.count).to eql(5)
        history = terminated_timeline.effective_history
        expect(history.count).to eql(4)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_20)
        expect(history[1].amount).to eql(10)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_20)
        expect(history[2].effective_till).to eql(sep_23)
        expect(history[2].amount).to eql(50)
        expect(history[2].currency).to eql("US")
        expect(history[2].interest).to eql(1)

        expect(history[3].effective_from).to eql(sep_23)
        expect(history[3].effective_till).to eql(infinite_date)
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to eql("IN")
        expect(history[3].interest).to eql(3)
        expect(history[3]).to be_effective_now
      end

      #     date: 05 -- 10 -- 20 -- 25
      #    value:    09    10    50
      # currency:    IN    SG    US
      # interest:     3     2     1
      # ------------update(amt:25,e.f:sep_28, e.t:sep_30,cur: "IN", int:3)--------------
      #     date: 05 -- 10 -- 20 -- 25:28 -- 30
      #    value:    09    10    50       25
      # currency:    IN    SG    US       nil
      # interest:     3     2     1       nil
      it "with effective_from and effective till in future date range" do
        terminated_timeline.update({amount: 25, currency: "IN", interest: 3}, effective_from: sep_28, effective_till: sep_30)
        expect(balance_klass.count).to eql(5)
        expect(balance_klass.historically_valid.count).to eql(5)
        history = terminated_timeline.effective_history
        expect(history.count).to eql(4)

        expect(history[0].effective_from).to eql(sep_5)
        expect(history[0].effective_till).to eql(sep_10)
        expect(history[0].amount).to eql(9)
        expect(history[0].currency).to eql("IN")
        expect(history[0].interest).to eql(3)

        expect(history[1].effective_from).to eql(sep_10)
        expect(history[1].effective_till).to eql(sep_20)
        expect(history[1].amount).to eql(10)
        expect(history[1].currency).to eql("SG")
        expect(history[1].interest).to eql(2)

        expect(history[2].effective_from).to eql(sep_20)
        expect(history[2].effective_till).to eql(sep_25)
        expect(history[2].amount).to eql(50)
        expect(history[2].currency).to eql("US")
        expect(history[2].interest).to eql(1)

        expect(history[3].effective_from).to eql(sep_28)
        expect(history[3].effective_till).to eql(sep_30)
        expect(history[3].valid_from.to_time).to be_between(current_time.to_time - 5.seconds, current_time.to_time + 5.seconds )
        expect(history[3].amount).to eql(25)
        expect(history[3].currency).to eql("IN")
        expect(history[3].interest).to eql(3)
      end
    end
  end

  describe "update! pre historic trails" do
    before do
      timeline.update({amount: 10, currency: "SG"}, effective_from: sep_10, effective_till: sep_20)
      timeline.update({amount: 9, currency: "IN"}, effective_from: sep_5, effective_till: sep_10)
    end

    #     date: 05 -- 10 -- 20 -- infi
    #    value:    09    10    50
    # currency:    IN    SG    US
    # ------------update--------------
    #     date: 02 -- 05 -- 10 -- 20 -- infi
    #    value:    07    09    10    50
    # currency:    US    IN    SG    US
    it "with effective_from set to date before history and effective till to start of history" do
      timeline.update({amount: 7, currency: "US"}, effective_from: sep_2, effective_till: sep_5)

      history = timeline.effective_history
      expect(history.count).to eql(4)

      expect(history[0].effective_from).to eql(sep_2)
      expect(history[0].effective_till).to eql(sep_5)
      expect(history[0].amount).to eql(7)
      expect(history[0].currency).to eql("US")

      expect(history[1].effective_from).to eql(sep_5)
      expect(history[1].effective_till).to eql(sep_10)
      expect(history[1].amount).to eql(9)
      expect(history[1].currency).to eql("IN")

      expect(history[2].effective_from).to eql(sep_10)
      expect(history[2].effective_till).to eql(sep_20)
      expect(history[2].amount).to eql(10)
      expect(history[2].currency).to eql("SG")

      expect(history[3].effective_from).to eql(sep_20)
      expect(history[3]).to be_effective_now
      expect(history[3].amount).to eql(50)
      expect(history[3].currency).to eql("US")
    end

    #     date: 05 -- 10 -- 20 -- infi
    #    value:    09    10    50
    # currency:    IN    SG    US
    # ------------update--------------
    #     date: 02 -- 05 -- 10 -- 20 -- infi
    #    value:    07    09    10    50
    # currency:    --    IN    SG    US
    it "with effective_from set to date before history and effective till to start of history" do
      timeline.update({amount: 7}, effective_from: sep_2, effective_till: sep_5)

      history = timeline.effective_history
      expect(history.count).to eql(4)

      expect(history[0].effective_from).to eql(sep_2)
      expect(history[0].effective_till).to eql(sep_5)
      expect(history[0].amount).to eql(7)
      expect(history[0].currency).to be_nil
    end
  end

  describe "update! post historic trails" do
    before do
      timeline.update({amount: 10, currency: "SG"}, effective_from: sep_10, effective_till: sep_20)
      timeline.update({amount: 9, currency: "IN"}, effective_from: sep_5, effective_till: sep_10)
    end

    #     date: 05 -- 10 -- 20 -- infi
    #    value:    09    10    50
    # currency:    IN    SG    US
    # ------------update--------------
    #     date: 05 -- 10 -- 20 -- 25 -- infi
    #    value:    09    10    50    60
    # currency:    IN    SG    US    US
    it "with effective_from set to post histoy date" do
      timeline.update({amount: 60}, effective_from: sep_25)

      history = timeline.effective_history
      expect(history.count).to eql(4)

      expect(history[0].effective_from).to eql(sep_5)
      expect(history[0].effective_till).to eql(sep_10)
      expect(history[0].amount).to eql(9)
      expect(history[0].currency).to eql("IN")

      expect(history[1].effective_from).to eql(sep_10)
      expect(history[1].effective_till).to eql(sep_20)
      expect(history[1].amount).to eql(10)
      expect(history[1].currency).to eql("SG")

      expect(history[2].effective_from).to eql(sep_20)
      expect(history[2].effective_till).to eql(sep_25)
      expect(history[2].amount).to eql(50)
      expect(history[2].currency).to eql("US")

      expect(history[3].effective_from).to eql(sep_25)
      expect(history[3]).to be_effective_now
      expect(history[3].amount).to eql(60)
      expect(history[3].currency).to eql("US")
    end
  end
end
