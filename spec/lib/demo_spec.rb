require 'rails_helper'
require "pp"
require "timecop"
require "json"

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

  let(:day_1) { (Date.today - 2.days).beginning_of_day }
  let(:deposit_1) { (day_1 - 5.days).beginning_of_day }
  let(:deposit_2) { (day_1 - 2.days).beginning_of_day }
  let(:day_2) { (Date.today - 1.days).beginning_of_day }
  let(:day_3) { Date.today.beginning_of_day }
  let(:infinite_date) { TimeTravel::INFINITE_DATE}

  let(:cash_account_id) { 1 }

  let(:timeline) {
    balance_klass.timeline(cash_account_id: cash_account_id)
  }

  describe "demo" do
    context "should work" do
      xit "example 1" do
        Timecop.freeze(day_1) do
          pp "Day 1 - #{Time.now}"
          timeline.create({ amount: 500 }, effective_from: deposit_1)
          timeline.update({ amount: 700 }, effective_from: deposit_2)
        end
         Timecop.freeze(day_2) do
          pp "Day 2 - #{Time.now}"
          timeline.update({ amount: 600 }, effective_from: deposit_1)
          timeline.update({ amount: 900 }, effective_from: deposit_2)
        end
        Timecop.freeze(day_3) do
          pp "Day 3 - #{Time.now}"
          pp "Current balance"
          pp JSON.parse(timeline.at(Time.now).to_json)
          pp "Balance which the customer saw 2 days ago"
          pp JSON.parse(timeline.at(Time.now - 2.days, as_of: Time.now - 2.days).to_json)
          pp "Inaccurate balance trail recorded 2 days ago"
          pp JSON.parse(timeline.as_of(Time.now - 2.days).to_json)
          pp "Accurate balance trail recorded 1 day ago"
          pp JSON.parse(timeline.as_of(Time.now - 1.days).to_json)
        end
      end
    end
  end

end
