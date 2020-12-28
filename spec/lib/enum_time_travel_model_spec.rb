require 'rails_helper'

describe TimeTravel do

  let(:klass) do
    Class.new(ActiveRecord::Base) do
      self.table_name = 'performance_data'
      include TimeTravel
      default_scope { order(effective_from: :desc) }

      enum status: { recorded: 0, stale: 1, fresh: 2 }
      def self.time_travel_identifiers
        [:wrapper_id, :reporting_currency]
      end

      def self.batch_size
        1000
      end
    end
  end

  let(:wrapper_id) { 12 }
  let(:reporting_currency) { "SGD" }
  let(:amount) { 150 }
  let(:effective_from) { DateTime.parse('01-01-2020') }

  describe 'create' do
    it "creates new record with timestamps set" do
      new_obj = klass.create(amount: amount, wrapper_id: wrapper_id, status: 'stale',
        reporting_currency: reporting_currency, effective_from: effective_from)
      expect(new_obj).to be_persisted
      expect(new_obj.wrapper_id).to eql(wrapper_id)
      expect(new_obj).to be_stale
      expect(new_obj.reporting_currency).to eql(reporting_currency)
      expect(new_obj.amount).to eql(amount)
      expect(new_obj.effective_from.to_datetime).to eql(effective_from)
      expect(new_obj).to be_effective_now
      expect(new_obj).to be_valid_now
    end
  end

  describe 'update' do
    it "updates record with enum values" do
      new_effective_from = effective_from + 2.days
      new_obj = klass.create(amount: amount, wrapper_id: wrapper_id, status: 'stale',
        reporting_currency: reporting_currency, amount: amount, effective_from: effective_from)
      new_obj.update!(status: 'fresh', amount: 200, effective_from: new_effective_from)

      expect(new_obj).to be_persisted
      expect(new_obj.wrapper_id).to eql(wrapper_id)
      expect(new_obj).to be_fresh
      expect(new_obj.reporting_currency).to eql(reporting_currency)
      expect(new_obj.amount).to eql(200)
      expect(new_obj.effective_from.to_datetime).to eql(new_effective_from)
      expect(new_obj).to be_effective_now
      expect(new_obj).to be_valid_now

      old_obj = klass.as_of(effective_from, wrapper_id, reporting_currency)
      expect(old_obj.effective_from.to_datetime).to eql(effective_from)
      expect(old_obj.effective_till.to_datetime).to eql(new_effective_from)
      expect(old_obj).to be_stale
      expect(old_obj.amount).to eql(amount)
    end
  end
end
