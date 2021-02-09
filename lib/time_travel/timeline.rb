require "time_travel/sql_function_helper"
require "time_travel/update_helper"

class Timeline
  include UpdateHelper
  UPDATE_MODE=ENV["TIME_TRAVEL_UPDATE_MODE"] || TimeTravel.configuration.update_mode

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
    effective_attributes=attributes
    effective_record=self.effective_at(effective_from)
    # if not effective_record.nil?
    #  effective_attributes=effective_record.attributes.except(*ignored_copy_attributes)
    #  effective_attributes.merge(attributes)
    # end
    record.attributes=effective_attributes
    @timeline_identifiers.each do |attribute,value|
      record[attribute]=value
    end
    record.current_time=current_time
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
    raise ActiveRecord::RecordInvalid.new(record) unless record.validate_update(attributes)
    record.save!
    record
  end

  def self.bulk_update(model_class, attribute_set, current_time: Time.current, latest_transactions: false)
    if UPDATE_MODE=="native"
      attribute_set.each do |attributes|
        attributes.symbolize_keys!
        if attributes.slice(*model_class.timeline_fields).keys.length != model_class.timeline_fields.length
          raise "Timeline identifiers can't be empty"
        end
        timeline=model_class.timeline(attributes.slice(*model_class.timeline_fields))
        timeline.create_or_update(
          attributes, 
          current_time: current_time, 
          effective_from: attributes[:effective_from], 
          effective_till: attributes[:effective_till]
        )
      end
    else
      update_sql(
        model_class,
        attribute_set, 
        current_time: current_time, 
        latest_transactions: latest_transactions
      )
    end
  end

  def update(attributes, current_time: Time.current, effective_from: nil, effective_till: nil)
    return true if attributes.symbolize_keys!.empty?
    if not self.has_history?
      raise "timeline not found"
    end
    record=construct_record(
      attributes, current_time: current_time, effective_from: effective_from, effective_till: effective_till)
    raise ActiveRecord::RecordInvalid.new(record) unless record.validate_update(attributes)
    update_attributes=attributes.except(*ignored_update_attributes)
    if UPDATE_MODE=="native"
      update_native(
        record, update_attributes, 
        current_time: current_time, effective_from: effective_from, effective_till: effective_till
      )
    else
      self.class.update_sql(@model_class, [update_attributes], current_time: current_time)
    end
  end
 

  def update_native(record, update_attributes, current_time: Time.current, effective_from: nil, effective_till: nil)
    affected_records = fetch_history_for_correction(record)
    affected_timeframes = get_affected_timeframes(record, affected_records)

    corrected_records = construct_corrected_records(
      record, affected_timeframes, affected_records, update_attributes)
    squished_records = squish_record_history(corrected_records)

    @model_class.transaction do
      squished_records.each do |record|
        insert_record=record.merge(
          current_time: current_time
        )
        # pp insert_record
        @model_class.create!(insert_record)
      end

      affected_records.each {|record| record.update_attribute(:valid_till, current_time)}
    end
    true
  end

  def self.update_sql(model_class, attribute_set, current_time: Time.current, latest_transactions: false)
    other_attrs = (model_class.column_names - ["id", "created_at", "updated_at", "valid_from", "valid_till"])
    empty_obj_attrs = other_attrs.map{|attr| {attr => nil}}.reduce(:merge!).with_indifferent_access
    query = ActiveRecord::Base.connection.quote(model_class.unscoped.where(valid_till: TimeTravel::INFINITE_DATE).to_sql)
    table_name = ActiveRecord::Base.connection.quote(model_class.table_name)

    attribute_set.each_slice(model_class.batch_size).to_a.each do |batched_attribute_set|
      batched_attribute_set.each do |attrs|
        attrs.symbolize_keys!
        set_enum(model_class, attrs)
        attrs[:timeline_clauses], attrs[:update_attrs] = attrs.partition do  |key, value|
          key.in?(model_class.timeline_fields)
        end.map(&:to_h).map(&:symbolize_keys!)
        if attrs[:timeline_clauses].empty? || attrs[:timeline_clauses].values.any?(&:blank?)
          raise "Timeline identifiers can't be empty"
        end
        obj_current_time = attrs[:update_attrs].delete(:current_time) || current_time
        attrs[:effective_from] = db_timestamp(attrs[:update_attrs].delete(:effective_from) || obj_current_time)
        attrs[:effective_till] = db_timestamp(attrs[:update_attrs].delete(:effective_till) || TimeTravel::INFINITE_DATE)
        attrs[:current_time] = db_timestamp(obj_current_time)
        attrs[:infinite_date] = db_timestamp(TimeTravel::INFINITE_DATE)
        attrs[:empty_obj_attrs] = empty_obj_attrs.merge(attrs[:timeline_clauses])
      end
      attrs = ActiveRecord::Base.connection.quote(batched_attribute_set.to_json)
      begin
        result = ActiveRecord::Base.connection.execute("select update_bulk_history(#{query},#{table_name},#{attrs},#{latest_transactions})")
      rescue => e
        ActiveRecord::Base.connection.execute 'ROLLBACK'
        raise e
      end
    end
  end
  
  def self.set_enum(model_class, attrs)
    enum_fields, enum_items = model_class.enum_info
    enum_fields.each do |key|
      string_value = attrs[key]
      attrs[key] = enum_items[key][string_value] unless string_value.blank?
    end
  end

  def self.db_timestamp(datetime)
    datetime.to_datetime.utc.strftime(TimeTravel::PRECISE_TIME_FORMAT)
  end

  def terminate(current_time: Time.current, effective_till: nil)
    effective_record = self.effective_history.where(effective_till: TimeTravel::INFINITE_DATE).first
    if effective_record.present?
      attributes = effective_record.attributes.except(*ignored_copy_attributes)
      @model_class.transaction do
        @model_class.create!(
          attributes.merge(
            effective_till: (effective_till || current_time),
            current_time: current_time
          )
        )
        effective_record.update_attribute(:valid_till, current_time)
      end
    else
      raise "no effective record found on timeline"
    end
  end

  def ignored_update_attributes
    ["id", "created_at", "updated_at", "effective_from", "effective_till", "valid_from", "valid_till"]
  end

  def ignored_copy_attributes
    ["id", "created_at", "updated_at", "valid_from", "valid_till"]
  end

  def has_history?
    effective_history.exists?
  end
end
