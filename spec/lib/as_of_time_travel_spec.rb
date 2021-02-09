require 'rails_helper'

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
  let(:sep_26) { Date.parse('26/09/2018').beginning_of_day }
  let(:sep_28) { Date.parse('28/09/2018').beginning_of_day }
  let(:sep_30) { Date.parse('30/09/2018').beginning_of_day }
  let(:infinite_date) { balance_klass::INFINITE_DATE }

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

  let(:timeline3) {
    balance_klass.timeline(cash_account_id: 3)
  }

  let!(:balance) { balance_klass.create(amount: amount, currency: "US", interest: 1, cash_account_id: cash_account_id,
    effective_from: sep_20)}
  let!(:balance_definiteEffective) { balance_klass.create(amount: amount, currency: "US" , interest: 1, cash_account_id: cash_account_id_for_definite_effectiveness,
    effective_from: sep_20,effective_till: sep_25)}

  describe "AsOf to fetch records" do
    before do
      timeline.update({amount: 9, currency: "IN",interest: 3}, effective_from: sep_5, effective_till: sep_10)
      timeline.update({amount: 10, currency: "SG",interest: 2}, effective_from: sep_10, effective_till: sep_20)
      timeline.update({amount: 15, currency: "IN", interest: 3}, effective_from: sep_21, effective_till: sep_25)
      terminated_timeline.update({amount: 25, currency: "IN", interest:3}, effective_from: sep_28, effective_till:sep_30)
    end
    context " validations " do
      it "returns record when valid identifier being passed " do
        record = timeline.effective_at(sep_19)
        expect(record).to be_present
      end

      it "returns null when identifier being passed does not have history " do
        record = timeline3.effective_at(sep_19)
        expect(record).to be_nil
      end

      # it "retruns null when inavlid date argument passed " do
      #   record = balance_klass.as_of("2018/09/19 00:00:00 +0530", cash_account_id)
      #   expect(record).to be_nil
      # end
    end
    # working record data: ######################
    #   id cash_account_id balance currency interest effective_from effective_till valid_from valid_till
    #    1     1                9    IN       3          sep_5         sep_10          cur        inf
    #    2     1               10    SG       2          sep_10        sep_20          cur        inf
    #    3     1               50    US       1          sep_20        inf             cur        cur
    #    4     1               50    US       2          sep_20        sep_21          cur        inf
    #    5     1               15    IN       3          sep_21        sep_25          cur        inf
    #    6     1               50    US       1          sep_25        inf             cur        inf
    #    7     2               50    US       1          sep_20        sep_25          cur        inf
    #    8     2               25    IN       3          sep_28        sep_30          cur        inf

    context " when searched for record data within the history " do
      it " with date inbetween definite effective record" do
        record = timeline.effective_at(sep_19)
        expect(record.cash_account_id).to eql(cash_account_id)
        expect(record.effective_from).to eql(sep_10)
        expect(record.effective_till).to eql(sep_20)
        expect(record.amount).to eql(10)
        expect(record.currency).to eql("SG")
        expect(record.interest).to eql(2)
      end

      it "with date equal to inbound effective range" do
        record = timeline.effective_at(sep_10)

        expect(record.cash_account_id).to eql(cash_account_id)
        expect(record.effective_from).to eql(sep_10)
        expect(record.effective_till).to eql(sep_20)
        expect(record.amount).to eql(10)
        expect(record.currency).to eql("SG")
        expect(record.interest).to eql(2)
      end

      it "with date equal to outbound effective range" do
        record = timeline.effective_at(sep_19.end_of_day)

        expect(record.cash_account_id).to eql(cash_account_id)
        expect(record.effective_from).to eql(sep_10)
        expect(record.effective_till).to eql(sep_20)
        expect(record.amount).to eql(10)
        expect(record.currency).to eql("SG")
        expect(record.interest).to eql(2)
      end

      it " with date is in future of an infinite effective record" do
        record = timeline.effective_at(sep_28)

        expect(record.cash_account_id).to eql(cash_account_id)
        expect(record.effective_from).to eql(sep_25)
        expect(record.effective_till).to eql(infinite_date)
        expect(record.amount).to eql(50)
        expect(record.currency).to eql("US")
        expect(record.interest).to eql(1)
      end
    end

    context " when searched for record data outside the history " do
      it " with date lesser than definite effective record" do
        record = timeline.effective_at(sep_2)
        expect(record).to be_nil
      end

      it " with date time gap of definite effective records" do
        record = terminated_timeline.effective_at(sep_26)
        expect(record).to be_nil
      end
    end
  end
end
