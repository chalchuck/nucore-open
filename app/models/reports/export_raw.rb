class Reports::ExportRaw

  def initialize(facility, date_range_field = 'journal_or_statement_date', date_start, date_end, order_status_ids, headers, action_name)
    @action_name = action_name
    @date_end = date_end
    @date_range_field = date_range_field
    @date_start = date_start
    @headers = headers
    @facility = facility
    @order_status_ids = order_status_ids
  end

  def report_data
    @report_data ||= report_data_query
  end

  def to_csv
    (csv_header + csv_body).to_s
  end

  def filename
    "#{@action_name}_#{formatted_compact_date_range}.csv"
  end

  def description
    "#{@action_name.capitalize} Raw Export, #{formatted_date_range}"
  end

  def formatted_date_range
    "#{formatted_date(@date_start)} - #{formatted_date(@date_end)}"
  end

  def formatted_compact_date_range
    "#{@date_start.strftime("%Y%m%d")}-#{@date_end.strftime("%Y%m%d")}"
  end

  private

  def csv_header
    @headers.to_csv
  end

  def basic_info_columns(order_detail)
    [
      order_detail.facility,
      order_detail.to_s,
      formatted_datetime(order_detail.order.ordered_at),
      formatted_datetime(order_detail.fulfilled_at),
      order_detail.order_status.name,
      order_detail.state,
    ]
  end

  def user_info_columns(user)
    [
      user.username,
      user.first_name,
      user.last_name,
      user.email,
    ]
  end

  def product_info_columns(order_detail)
    product = order_detail.product
    bundle_desc = product.is_a?(Bundle) ? product.products.collect(&:name).join(' & ') : nil
    [
      product.url_name,
      product.type.underscore.humanize,
      product.name,
      order_detail.quantity,
      bundle_desc,
    ]
  end

  def account_info_columns(account)
    [
      account.type.underscore.humanize,
      account.affiliate_to_s,
      account.account_number,
      account.description,
      formatted_datetime(account.expires_at)
    ]
  end

  def pricing_info_columns(order_detail)
    [
      order_detail.price_policy.try(:price_group).try(:name),
      as_currency(order_detail.estimated_cost),
      as_currency(order_detail.estimated_subsidy),
      as_currency(order_detail.estimated_total),
      as_currency(order_detail.actual_cost),
      as_currency(order_detail.actual_subsidy),
      as_currency(order_detail.actual_total),
    ]
  end

  def reservation_info_columns(reservation)
    if reservation.present?
      [
        formatted_datetime(reservation.reserve_start_at),
        formatted_datetime(reservation.reserve_end_at),
        reservation.duration_mins,
        formatted_datetime(reservation.actual_start_at),
        formatted_datetime(reservation.actual_end_at),
        reservation.actual_duration_mins,
        formatted_datetime(reservation.canceled_at),
        canceled_by_name(reservation),
      ]
    else
      [nil, nil, nil, nil, nil, nil, nil, nil]
    end
  end

  def dispute_info_columns(order_detail)
    [
      formatted_datetime(order_detail.dispute_at),
      order_detail.dispute_reason,
      formatted_datetime(order_detail.dispute_resolved_at),
      order_detail.dispute_resolved_reason,
    ]
  end

  def statement_datetime_column(statement)
    [ statement.present? ? formatted_datetime(statement.created_at) : nil ]
  end

  def journal_datetime_column(journal)
    [ journal.present? ? formatted_datetime(journal.created_at) : nil ]
  end

  def order_detail_row(order_detail)
    begin
      basic_info_columns(order_detail) +
      user_info_columns(order_detail.order.created_by_user) +
      user_info_columns(order_detail.order.user) +
      product_info_columns(order_detail) +
      account_info_columns(order_detail.account) +
      user_info_columns(order_detail.account.owner_user) +
      pricing_info_columns(order_detail) +
      reservation_info_columns(order_detail.reservation) +
      [ order_detail.note ] +
      dispute_info_columns(order_detail) +
      [ formatted_datetime(order_detail.reviewed_at) ] +
      statement_datetime_column(order_detail.statement) +
      journal_datetime_column(order_detail.journal) +
      [ order_detail.reconciled_note ]
    rescue => e
      [ "*** ERROR WHEN REPORTING ON ORDER DETAIL #{order_detail}: #{e.message} ***" ]
    end
  end

  def csv_body
    CSVHelper::CSV.generate do |csv|
      report_data.each do |order_detail|
        csv << order_detail_row(order_detail)
      end
    end
  end

  def report_data_query
    return [] if @order_status_ids.blank?

    OrderDetail.where(order_status_id: @order_status_ids)
      .for_facility(@facility)
      .action_in_date_range(@date_range_field, @date_start, @date_end)
      .includes(:account, :order, :order_status, :price_policy, :product, :reservation, :statement)
  end

  def formatted_datetime(datetime)
    datetime.present? ? I18n.l(datetime, format: :usa) : ''
  end

  def formatted_date(datetime)
    I18n.l(datetime.to_date, format: :usa)
  end

  def as_currency(number)
    if number.present?
      ActionController::Base.helpers.number_to_currency(number)
    else
      ''
    end
  end

  def canceled_by_name(reservation)
    if reservation.canceled_by == 0
      I18n.t('reports.fields.auto_cancel_name')
    else
      reservation.canceled_by_user.try(:full_name)
    end
  end
end
