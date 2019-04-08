class HistoryController < ApplicationController

  def index
    require 'pp'
    require 'csv'

    abnormal_criteria = 1.46
    @totals = {}
    @builds = []
    CSV.foreach("#{Rails.root}/public/session_history.csv", col_sep: ',', row_sep: :auto, headers: true) do |row|
      parsed = Time.parse(row['created_at'])
      day = parsed.strftime("%Y-%m-%d")
      @totals[day] ||= {}
      @totals[day][:passed] ||= 0
      @totals[day][:passed] += 1 if row['summary_status'] == 'passed'
      @totals[day][:failed] ||= 0
      @totals[day][:failed] += 1 if ['error','failed'].include?row['summary_status']

      @builds << [parsed.strftime("%Y-%m-%d"), row['duration']]
    end

    errors_rate_summ = 0
    @totals.each do |item|
      total  = (item[1][:passed] + item[1][:failed])
      errors_rate = total > 1 ? (item[1][:failed].to_f / total.to_f).round(2) : 0
      item[1][:errors_rate] = errors_rate
      errors_rate_summ += errors_rate
    end

    average = (errors_rate_summ / @totals.size)
    variance = @totals.inject(0) { |memo, x| memo + ((x[1][:errors_rate] - average)**2) }
    standard_dev = Math.sqrt(variance / @totals.size).round(2)

    total_arr = @totals.to_a
    @totals.each_with_index do |item, j|
      if j == 0
        total_arr[j][1][:abnormal] = 0
        next
      end
      if total_arr[j-1][1][:abnormal] > 0
        total_arr[j][1][:abnormal] = 0
        next
      end
      dev = (total_arr[j][1][:errors_rate] - total_arr[j-1][1][:errors_rate]).abs
      abnormal = dev / standard_dev
      total_arr[j][1][:abnormal] = abnormal >= abnormal_criteria ? abnormal.round(2) : 0
    end

  end
end
