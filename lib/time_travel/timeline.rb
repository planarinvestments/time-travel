require "time_travel/sql_function_helper"
require "time_travel/update_helper"

class Timeline
  include UpdateHelper
  def initialize(model_class,**timeline_identifiers)
    @model_class=model_class
    @timeline_identifiers=timeline_identifiers
    @timeline=model_class.where(**timeline_identifiers)
  end

  def effective_history
    @timeline.where(valid_till: TimeTravel::INFINITE_DATE).order("effective_from ASC")
  end

  def effective_at(effective_date)
    effective_record = effective_history
        .where("effective_from <= ?", effective_date)
        .where("effective_till > ?", effective_date)
    effective_record.first if effective_record.exists?
  end

  def construct_record(attributes,current_time:,effective_from:,effective_till:)
    record=@model_class.new
    record.current_time=current_time
    attributes.each do |attribute,value|
      record[attribute]=value
    end
    @timeline_identifiers.each do |attribute,value|
      record[attribute]=value
    end
    record.effective_from=effective_from
    record.effective_till=effective_till
    record
  end

  def create_or_update(attributes,current_time: Time.current, effective_from: nil, effective_till: nil)
    if self.has_history?
      self.update(
        attributes, current_time: current_time, effective_from: effective_from, effective_till: effective_till)
    else
      self.create(
        attributes,current_time: current_time, effective_from: effective_from, effective_till: effective_till)
    end
  end

  def create(attributes,current_time: Time.current, effective_from: nil, effective_till: nil)
    record=construct_record(attributes, current_time: current_time, 
                            effective_from: effective_from, effective_till: effective_till)
    if self.has_history?
      raise "timeline already exists"
    end
    raise(ActiveRecord::RecordInvalid.new(record)) unless record.validate_update(attributes)
    record.save!
    record
  end

  def update(attributes, current_time: Time.current, effective_from: nil, effective_till: nil)
    return true if attributes.symbolize_keys!.empty?
    record=construct_record(attributes, current_time: current_time, effective_from: nil, effective_till: nil)
    if not self.has_history?
      raise "timeline not found"
    end
    raise(ActiveRecord::RecordInvalid.new(self)) unless record.validate_update(attributes)

    affected_records = fetch_history_for_correction(record)
    affected_timeframes = get_affected_timeframes(record, affected_records)

    corrected_records = construct_corrected_records(record, affected_timeframes, affected_records, attributes)
    squished_records = squish_record_history(corrected_records)

    @model_class.transaction do
      squished_records.each do |record|
        @model_class.create!(
          record.merge(
            call_original: true,
            valid_from: current_time,
            valid_till: TimeTravel::INFINITE_DATE)
        )
      end

      affected_records.each {|record| record.update_attribute(:valid_till, current_time)}
    end
    true
  end

  def terminate(current_time: Time.current, effective_till: nil)
    effective_record = self.effective_history.where(effective_till: TimeTravel::INFINITE_DATE).first
    if effective_record.present?
      attributes = effective_record.attributes.except(*ignored_copy_attributes)
      @model_class.transaction do
        @model_class.create!(
          attributes.merge(
            call_original: true,
            effective_till: (effective_till || current_time),
            valid_from: current_time,
            valid_till: TimeTravel::INFINITE_DATE)
        )
        effective_record.update_attribute(:valid_till, current_time)
      end
    else
      raise "no effective record found on timeline"
    end
  end

  def ignored_copy_attributes
    ["id", "created_at", "updated_at", "valid_from", "valid_till"]
  end

  def has_history?
    effective_history.exists?
  end
end

