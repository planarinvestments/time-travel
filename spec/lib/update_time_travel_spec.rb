require 'rails_helper'
require "pp"

describe TimeTravel do

  let(:balance_klass) do
    Class.new(ActiveRecord::Base) do
      self.table_name = 'balances'
      include TimeTravel::TimelineHelper

      def self.timeline_fields
        [:cash_account_id]
      end

      def self.batch_size
        3000
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
  let(:infinite_date) { TimeTravel::INFINITE_DATE}

  let(:cash_account_id) { 1 }
  let(:amount) { 50 }
  let(:current_time) {Time.current}
  let(:cash_account_id_for_definite_effectiveness) { 2 }

  let(:timeline) {
    balance_klass.timeline(cash_account_id: cash_account_id)
  }

  let(:terminated_timeline) {
    balance_klass.timeline(cash_account_id: cash_account_id_for_definite_effectiveness)
  }

  let!(:balance) { 
    attrs={ amount: amount }
    timeline.create(attrs, effective_from: sep_20)
    timeline.effective_at(sep_20)
  }
  let!(:terminated_balance) { 
    attrs={ amount: amount }
    terminated_timeline.create(attrs, effective_from: sep_20, effective_till: sep_25)
    terminated_timeline.effective_at(sep_20)
  }

  describe "validations" do
    context "update" do
      it "raises error when effective_from is greater than effective_till" do
        expect{
          attrs={ amount: amount }
          timeline.update(attrs, effective_from: sep_10, effective_till: sep_2)
        }.to raise_error { |e|
          expect(e).to be_a(ActiveRecord::RecordInvalid)
          expect(e.record.errors.full_messages).to include("effective_from can't be greater than effective_till")
        }
      end

      it "raises error when passed identifier that has no exiting history" do
        empty_timeline=balance_klass.timeline(cash_account_id: 3)
        expect {
          attrs={ amount: 10 }
          empty_timeline.update(attrs, effective_from: sep_21)
        }.to raise_error("timeline not found")
        history = timeline.effective_history
        expect(history.count).to eql(1)
      end

      it "raises no error when passed identifier that has exiting history" do
        expect{
          attrs={ amount: 10 }
          timeline.update(attrs, effective_from: sep_21)
        }.not_to raise_error
        history = timeline.effective_history
        expect(history.count).to eql(2)
      end

      it "returns true and does not Update when no Attributes passed to Update other than effective_from" do
        attrs={}
        expect(
          timeline.update(attrs, effective_from: sep_21)
        ).to be_truthy

        history=timeline.effective_history

        expect(history.count).to eql(1)
      end
    end

    # TIMELINE_REFACTOR_OMISSION
    context "update" do
      xit "returns false when effective_from is greater than effective_till" do
        attrs={ amount: 10 }
        expect(
          timeline.update(attrs, effective_from: sep_10, effective_till: sep_2)
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
      attrs={ amount: 10 }
      pp "Updating for test case"
      timeline.update(attrs)

      expect(balance_klass.count).to eql(4)
      expect(balance_klass.historically_valid.count).to eql(3)

      history = timeline.effective_history
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
      attrs={ amount: 10 }
      new_effective_from = Date.parse('21/09/2018').beginning_of_day
      timeline.update(attrs, effective_from: new_effective_from)

      history = timeline.effective_history
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
      attrs={ amount: 10 }
      timeline.update(attrs, effective_from: sep_19, effective_till: sep_20)

      history = timeline.effective_history
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
      attrs={ amount: 10 }
      timeline.update(attrs, effective_from: sep_18, effective_till: sep_25)
      history = timeline.effective_history
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
      attrs={ amount: 10 }
      timeline.update(attrs, effective_from: sep_15, effective_till: sep_19)

      history = timeline.effective_history
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
      attrs={ amount: 10 }
      timeline.update(attrs, effective_from: sep_20)

      history = timeline.effective_history
      expect(history.count).to eql(1)

      expect(history.first.amount).to eql(10)
      expect(history.first.effective_from).to eql(sep_20)
      expect(history.first.effective_till).to be_present
      expect(history.first.valid_from).to be_present
    end
  end

  describe "#update! 2 historic trails" do
    before do
      attrs={ amount: 10 }
      timeline.update(attrs, effective_from: sep_10, effective_till: sep_20)
    end

    #  date: 10 -- 20 -- infi
    # value:    10    50
    # ------------update--------------
    #  date: 10 -- 20 -- 25 -- infi
    # value:    10    50    25
    it "with effective_from is set to date after existing history" do
      attrs={ amount: 25 }
      timeline.update(attrs, effective_from: sep_25)

      history = timeline.effective_history
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
      attrs={ amount: 31 }
      timeline.update(attrs, effective_from: sep_5)

      history = timeline.effective_history
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
      attrs={ amount: 25 }
      timeline.update(attrs, effective_from: sep_15, effective_till: sep_25)

      history = timeline.effective_history
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
      attrs={ amount: 25 }
      timeline.update(attrs, effective_from: sep_15, effective_till: sep_20)

      history = timeline.effective_history
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
     attrs={ amount: 25 }
     timeline.update(attrs, effective_from: sep_15, effective_till: sep_18)

     history = timeline.effective_history
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
      attrs={ amount: 10 }
      timeline.update(attrs, effective_from: sep_10, effective_till: sep_20)
      attrs={ amount: 9 }
      timeline.update(attrs, effective_from: sep_5, effective_till: sep_10)
    end

    #  date: 05 -- 10 -- 20 -- infi
    # value:    09    10    50
    # ------------update--------------
    #  date: 05 -- 10 -- 20 -- 25 -- infi
    # value:    09    10    50    25
    it "with effective_from set to date after existing history" do
      attrs={ amount: 25 }
      timeline.update(attrs, effective_from: sep_25)

      history = timeline.effective_history
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
      attrs={ amount: 5 }
      timeline.update(attrs, effective_from: sep_2, effective_till: sep_5)

      history = timeline.effective_history
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
      attrs={ amount: 80 }
      timeline.update(attrs, effective_from: sep_2)

      history = timeline.effective_history
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
      attrs={ amount: 25 }
      timeline.update(attrs, effective_from: sep_2, effective_till: sep_15)
      history = timeline.effective_history
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
      attrs={ amount: 25 }
      timeline.update(attrs, effective_from: sep_8, effective_till: sep_15)

      history = timeline.effective_history
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
        current_time = Time.current.utc
        attrs={ amount: 10 }
        terminated_timeline.update(attrs, current_time: current_time)
        expect(balance_klass.count).to eql(3)
        expect(balance_klass.historically_valid.count).to eql(3)

        history = terminated_timeline.effective_history
        expect(history.count).to eql(2), "Expected to create new record for Update with the given data"

        expect(history.first.effective_from).to eql(sep_20)
        expect(history.first.effective_till).to eql(sep_25)
        expect(history.first.amount).to eql(50)

        expect(history.last.amount).to eql(10)
        expect(history.last.effective_from.utc).to be_between(current_time-5.seconds, current_time + 5.seconds)
        expect(history.last.effective_till).to eql(infinite_date)
        expect(history.last.valid_from.utc).to be_between(current_time-5.seconds, current_time + 5.seconds)
        expect(history.last).to be_effective_now
      end

      #  date: 20 -- 25
      # value:    50
      # ------------update(10,e.f:15-Sep)--------------
      #  date: 15 -- infi
      # value:    10
      it " with effective_from set to date lesser than effective history" do
        attrs={ amount: 10 }
        terminated_timeline.update(attrs, effective_from: sep_15)

        expect(balance_klass.count).to eql(3)
        expect(balance_klass.historically_valid.count).to eql(2)

        history = terminated_timeline.effective_history
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
        attrs={ amount: 15 }
        terminated_timeline.update(attrs, effective_from: sep_15, effective_till:sep_19)
        attrs={ amount: 10 }
        terminated_timeline.update(attrs, effective_from: sep_18 , effective_till:sep_21)
        expect(balance_klass.count).to eql(6)
        expect(balance_klass.historically_valid.count).to eql(4)

        history = terminated_timeline.effective_history
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
        expect(history[1].valid_from.to_time).to be_between(current_time.to_time - 5.seconds, current_time.to_time + 5.seconds )
        expect(history[1].valid_till).to eql(infinite_date)

        expect(history[2].amount).to eql(50)
        expect(history[2].effective_from).to eql(sep_21)
        expect(history[2].effective_till).to eql(sep_25)
        expect(history[2].valid_from.to_time).to be_between(current_time.to_time - 5.seconds, current_time.to_time + 5.seconds )
        expect(history[2].valid_till).to eql(infinite_date)
      end
    end
  end

  describe "update_history" do
    it 'allows updating multiple records' do
      update_attrs =  [
        { amount: 10, effective_from: sep_15, effective_till: sep_19, cash_account_id: cash_account_id },
        { amount: 51, effective_from: sep_21, cash_account_id: cash_account_id_for_definite_effectiveness },
        { amount: 21, effective_from: sep_21, cash_account_id: 3 }
      ]

      Timeline.bulk_update(balance_klass, update_attrs)
      expect(balance_klass.count).to eql(6)

      histories = balance_klass.timeline(cash_account_id: cash_account_id).effective_history
      expect(histories.count).to eql(2)
      expect(histories.first.amount).to eql(10)
      expect(histories.first.effective_from).to eql(sep_15)
      expect(histories.first.effective_till).to eql(sep_19)
      expect(histories.first.valid_from).to be_present

      expect(histories.last.amount).to eql(50)
      expect(histories.last.effective_from).to eql(sep_20)
      expect(histories.last).to be_effective_now
      expect(histories.last.valid_from).to be_present

      histories = balance_klass.timeline(cash_account_id: cash_account_id_for_definite_effectiveness).effective_history
      expect(histories.count).to eql(2)

      expect(histories.first.amount).to eql(50)
      expect(histories.first.effective_from).to eql(sep_20)
      expect(histories.first.effective_till).to eql(sep_21)
      expect(histories.first.valid_from).to be_present

      expect(histories.last.amount).to eql(51)
      expect(histories.last.effective_from).to eql(sep_21)
      expect(histories.last).to be_effective_now
      expect(histories.last.valid_from).to be_present

      histories = balance_klass.timeline(cash_account_id: 3).effective_history
      expect(histories.count).to eql(1)
      expect(histories.first.amount).to eql(21)
      expect(histories.first.effective_from).to eql(sep_21)
      expect(histories.first).to be_effective_now
      expect(histories.first.valid_from).to be_present
      expect(histories.first).to be_valid_now
    end

    it 'raises exception when any time_travel_identfiers is blank' do
      update_attrs =  [
        { amount: 10, effective_from: sep_15, effective_till: sep_19, cash_account_id: cash_account_id},
        { amount: 51, effective_from: sep_21, cash_account_id: cash_account_id_for_definite_effectiveness },
        { amount: 21, effective_from: sep_21 }
      ]
      expect{
        balance_klass.transaction do
          Timeline.bulk_update(balance_klass, update_attrs)
        end
      }.to raise_error{"Timeline identifiers can't be empty"}

      expect(balance_klass.count).to eql(2)
    end

    context 'latest_transactions' do
      it "updates multiple records" do
        update_attrs =  [
          { amount: 10, effective_from: sep_21, cash_account_id: cash_account_id},
          { amount: 51, effective_from: sep_25, cash_account_id: cash_account_id },
          { amount: 21, effective_from: sep_21, cash_account_id: 3 }
        ]

        Timeline.bulk_update(balance_klass, update_attrs, latest_transactions: true)
        histories = balance_klass.timeline(cash_account_id: cash_account_id).effective_history
        expect(histories.count).to eql(3)

        expect(histories.first.amount).to eql(50)
        expect(histories.first.effective_from).to eql(sep_20)
        expect(histories.first.effective_till).to eql(sep_21)
        expect(histories.first.valid_from).to be_present

        expect(histories.second.amount).to eql(10)
        expect(histories.second.effective_from).to eql(sep_21)
        expect(histories.second.effective_till).to eql(sep_25)
        expect(histories.second.valid_from).to be_present

        expect(histories.last.amount).to eql(51)
        expect(histories.last.effective_from).to eql(sep_25)
        expect(histories.last).to be_effective_now
        expect(histories.last.valid_from).to be_present

        histories = balance_klass.timeline(cash_account_id: 3).effective_history
        expect(histories.count).to eql(1)
        expect(histories.first.amount).to eql(21)
        expect(histories.first.effective_from).to eql(sep_21)
        expect(histories.first).to be_effective_now
        expect(histories.first.valid_from).to be_present
        expect(histories.first).to be_valid_now
      end

      it "raises exception when non latest values given" do
        if TimeTravel.configuration.update_mode=="sql"
          update_attrs =  [
            { amount: 21, effective_from: sep_21, cash_account_id: 3 },
            { amount: 10, effective_from: sep_19, cash_account_id: cash_account_id},
            { amount: 51, effective_from: sep_25, cash_account_id: cash_account_id }
          ]
          expect{
            Timeline.bulk_update(balance_klass, update_attrs, latest_transactions: true)
          }.to raise_error(/you cannot update non latest values/)

          histories = balance_klass.timeline(cash_account_id: cash_account_id).effective_history
          expect(histories.count).to eql(0)
        end
      end
    end

    xit 'performance testing different accounts' do
      create_attrs = (1..5_000).map do |i|
        { amount: 10, effective_from: sep_15, effective_till: sep_19, cash_account_id: i }
      end.flatten

      update_attrs = (1..5_000).map do |i|
        { amount: 20, effective_from: sep_18, effective_till: sep_21, cash_account_id: i }
      end.flatten

      p (Benchmark.measure do
        balance_klass.update_history(create_attrs)
      end.inspect)

      p (Benchmark.measure do
        balance_klass.update_history(update_attrs)
      end.inspect)

      expect(balance_klass.count).to eql(15004)
    end

    xit 'performance testing same account' do
      update_attrs = (1..3000).map do |i|
        from = sep_15 + i.seconds
        { amount: i, effective_from: from, cash_account_id: 100 }
      end.flatten

      p (Benchmark.measure do
        balance_klass.update_history(update_attrs)
      end.inspect)

      expect(balance_klass.count).to eql(6001)
    end
  end
end
