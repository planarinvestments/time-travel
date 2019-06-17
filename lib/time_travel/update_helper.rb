module UpdateHelper
  def fetch_history_for_correction
    correction_head = self.history
                        .where("effective_from <= ?", self.effective_from)
                        .where("effective_till > ?", self.effective_from).first
    correction_tail = self.history
                        .where("effective_from < ?", self.effective_till)
                        .where("effective_till >= ?", self.effective_till).first
    correction_range = self.history
                        .where("effective_from > ?", self.effective_from)
                        .where("effective_till < ?", self.effective_till)

    [correction_head, correction_range.to_a, correction_tail].flatten.compact.uniq
  end

  def get_affected_timeframes(affected_records)
    affected_timeframes = affected_records.map { |record| [record.effective_from, record.effective_till] }
    affected_timeframes << [self.effective_from, self.effective_till]
    affected_timeframes = affected_timeframes.flatten.uniq.sort
    affected_timeframes.each_with_index.map{|time, i| {from: time, till: affected_timeframes[i+1]} }[0..-2]
  end

  def construct_corrected_records(affected_timeframes, affected_records, update_attrs)
    affected_timeframes.map do |timeframe|
      matched_record = affected_records.find do |record|
        record.effective_from <= timeframe[:from] && record.effective_till >= timeframe[:till]
      end

      if matched_record
        attrs = matched_record.attributes.except(*ignored_copy_attributes)
        if timeframe[:from] >= self.effective_from && timeframe[:till] <= self.effective_till
          attrs.merge!(update_attrs)
        end
      else
        attrs = update_attrs
      end

      attrs.merge!(
        **timeline_clauses,
        effective_from: timeframe[:from],
        effective_till: timeframe[:till]).symbolize_keys
    end
  end

  def squish_record_history(corrected_records)
    squished = []

    corrected_records.each do |current|
      # fetch and compare last vs current record
      last_squished = squished.last
      effective_attr = [:effective_from, :effective_till]

      if last_squished &&
        if last_squished.except(*effective_attr) == current.except(*effective_attr) &&
            last_squished[:effective_till] == current[:effective_from]
          # remove last_squished and push squished attributes

          squished = squished[0..-2]
          squished << last_squished.merge(effective_from: last_squished[:effective_from],
                              effective_till: current[:effective_till])
        end
      else
        squished << current
      end
    end
    squished.compact
  end

  def ignored_copy_attributes
    ["id", "created_at", "updated_at", "valid_from", "valid_till"]
  end
end
