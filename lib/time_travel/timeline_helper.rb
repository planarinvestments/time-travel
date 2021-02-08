require 'rails'
require "time_travel/railtie"
require "time_travel/sql_function_helper"
require "time_travel/update_helper"
require "time_travel/configuration"

module TimeTravel::TimelineHelper
  extend ActiveSupport::Concern

  INFINITE_DATE = Time.find_zone('UTC').local(3000,1,1)
  PRECISE_TIME_FORMAT = "%Y-%m-%d %H:%M:%S.%6N"

  included do
    attr_accessor :current_time
    before_validation :set_current_time
    before_validation :set_effective_defaults
    before_create :set_validity_defaults

    validates_presence_of :effective_from
    validate :effective_range_timeline
    validate :absence_of_valid_from_till, on: :create

    scope :historically_valid, -> { where(valid_till: INFINITE_DATE) }
    scope :effective_now, -> { where(effective_till: INFINITE_DATE, valid_till: INFINITE_DATE) }
  end


  module ClassMethods
    attr_accessor :enum_fields, :enum_items

    def timeline_fields
      raise "timeline_fields should be defined to return the list of fields which identify a timeline in the record"
    end
    
    def timeline(**timeline_identifiers)
      Timeline.new(self,timeline_identifiers)
    end

    def enum_info
      self.enum_items ||= self.defined_enums.symbolize_keys
      self.enum_fields ||= self.enum_items.keys
      [self.enum_fields, self.enum_items]
    end

  end

  # set defaults
  def set_current_time
    self.current_time ||= Time.current
  end

  def set_effective_defaults
    self.effective_from ||= current_time
    self.effective_till ||= INFINITE_DATE
  end

  def set_validity_defaults
    self.valid_from ||= current_time
    self.valid_till ||= INFINITE_DATE
  end

  def has_history
    if self.class.has_history?
      self.errors.add("base", "create called on alread existing timeline")
    end
  end

  def no_history
    if not self.class.has_history?
      self.errors.add("base", "update called on timeline that doesn't exist")
    end
  end

  # validations
  def effective_range_timeline
    if self.effective_from > self.effective_till
      self.errors.add(:base, "effective_from can't be greater than effective_till")
    end
  end

  def absence_of_valid_from_till
    if self.valid_from.present? || self.valid_till.present?
      self.errors.add(:base, "valid_from and valid_till can't be set")
    end
  end

  def validate_update(attributes)
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

