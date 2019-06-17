require 'rails'
require "time_travel/railtie"
require "time_travel/update_helper"

module TimeTravel
  extend ActiveSupport::Concern
  include UpdateHelper

  INFINITE_DATE = Date.parse('2040-1-1').beginning_of_day

  included do

    attr_accessor :current_time, :create_on_update
    before_validation :set_current_time
    before_validation :set_effective_defaults
    before_create :set_validity_defaults

    validate :absence_of_valid_from_till, on: :create, unless: :create_on_update
    validates_presence_of :effective_from
    validate :effective_range_timeline
    validate :history_present, on: :create, unless: :create_on_update
    validate :history_absent, on: :update, unless: :create_on_update
    scope :historically_valid, -> { where(valid_till: INFINITE_DATE) }
  end

  module ClassMethods
    def time_travel_identifiers
      raise "Please implement time_travel_identifier method to return an array of indentifiers to fetch a single timeline"
    end

    def timeline_clauses(*identifiers)
      clauses = {}
      time_travel_identifiers.each do | identifier_key, index |
        clauses[identifier_key] = identifiers[0]
      end
      clauses
    end

    def history(*identifiers)
      where(valid_till: INFINITE_DATE, **timeline_clauses(identifiers)).order("effective_from ASC")
    end

    def as_of(effective_date, *identifiers)
      effective_record = history(*identifiers)
        .where("effective_from <= ?", effective_date)
        .where("effective_till > ?", effective_date)
      effective_record.first if effective_record.exists?
   end
  end

  def timeline_clauses
    clauses = {}
    self.class.time_travel_identifiers.each_with_index do | key |
      clauses[key] = self[key]
    end
    clauses
  end

  def history
    self.class.where(valid_till: INFINITE_DATE, **timeline_clauses).order("effective_from ASC")
  end

  def as_of(effective_date)
    effective_record = history
      .where("effective_from <= ?", effective_date)
      .where("effective_till > ?", effective_date)
    effective_record.first if effective_record.exists?
   end

  # set defaults
  def set_current_time
    self.current_time = Time.current
  end

  def set_effective_defaults
    self.effective_from ||= current_time
    self.effective_till ||= INFINITE_DATE
  end

  def set_validity_defaults
    self.valid_from ||= current_time
    self.valid_till ||= INFINITE_DATE
  end

  # validations
  def absence_of_valid_from_till
    if self.valid_from.present? || self.valid_till.present?
      self.errors.add(:base, "valid_from and valid_till can't be set")
    end
  end

  def effective_range_timeline
    if self.effective_from > self.effective_till
      self.errors.add(:base, "effective_from can't be greater than effective_till")
    end
  end

  def has_history?
    self.class.exists?(**timeline_clauses)
  end

  def history_present
    if self.has_history?
      self.errors.add(:base, "already has history")
    end
  end

  def history_absent
    if not self.has_history?
      self.errors.add(:base, "does not have history")
    end  
  end

  def update(attributes)
    base_update(attributes)
  end

  def update!(attributes)
    base_update(attributes, raise_error: true)
  end

  # def save(validate: false)
  #   super(self.attributes) and return if self.new_record?
  #   attributes = self.changes.map{|a| {a.first => a.last.last}}.reduce(:merge)
  #   base_update(attributes)
  # end

  def save!
    super and return if self.new_record? and self.create_on_update
    attributes = self.changes.map{|a| {a.first => a.last.last}}.reduce(:merge)
    base_update(attributes, raise_error: true)
  end

  def base_update(attributes, raise_error: false)
    begin
      return true if attributes.symbolize_keys!.empty?
      attributes = { effective_from: nil, effective_till: nil }.merge(attributes)
      raise(ActiveRecord::RecordInvalid.new(self)) unless validate_update(attributes, raise_error)

      affected_records = fetch_history_for_correction
      affected_timeframes = get_affected_timeframes(affected_records)

      corrected_records = construct_corrected_records(affected_timeframes, affected_records, attributes)
      squished_records = squish_record_history(corrected_records)

      self.class.transaction do
        squished_records.each do |record|
          self.class.create!(
            record.merge(
              create_on_update: true,
              valid_from: current_time,
              valid_till: INFINITE_DATE)
          )
        end

        affected_records.each {|record| record.update_attribute(:valid_till, current_time)}
      end
      true
    rescue => e
      raise e if raise_error
      p "encountered error on update - #{e.message}"
      false
    end
  end

  def destroy(effective_till: Time.current)
    base_delete(effective_till)
  end

  def destroy!(effective_till: Time.current)
    base_delete(effective_till, raise_error: true)
  end

  def delete(effective_till: Time.current)
    base_delete(effective_till)
  end

  def delete!(effective_till: Time.current)
    base_delete(effective_till, raise_error: true)
  end

  def base_delete(effective_till, raise_error: false)
    begin
      set_current_time
      effective_record = self.history.where(effective_till: INFINITE_DATE).first
      if effective_record.present?
        attributes = effective_record.attributes.except(*ignored_copy_attributes)
        self.class.transaction do
          self.class.create!(
            attributes.merge(
              create_on_update: true,
              effective_till: effective_till,
              valid_from: current_time,
              valid_till: INFINITE_DATE)
          )
          effective_record.update_attribute(:valid_till, current_time)
        end
      else
        raise "no effective record found"
      end
    rescue => e
      raise e if raise_error
      p "encountered error on delete - #{e.message}"
      false
    end
  end

  def validate_update(attributes, raise_error)
    self.assign_attributes(attributes)
    self.valid?
  end

  def invalid_now?
    !self.valid_now?
  end

  def valid_now?
    self.valid_from.present? and self.valid_till==INFINITE_DATE
  end

  def ineffective_now?
    !self.effective_now?
  end

  def effective_now?
    self.effective_from.present? and self.effective_till==INFINITE_DATE
  end
end
