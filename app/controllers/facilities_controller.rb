class FacilitiesController < ApplicationController
  customer_tab  :index, :list, :show
  admin_tab     :edit, :manage, :schedule, :update, :agenda, :transactions,
                :reassign_chart_strings, :movable_transactions, :confirm_transactions, :move_transactions
  before_filter :authenticate_user!, :except => [:index, :show]  # public pages do not require authentication
  before_filter :check_acting_as, :except => [:index, :show]
  before_filter :load_order_details, only: [:confirm_transactions, :move_transactions, :reassign_chart_strings]
  before_filter :set_admin_billing_tab, only: [:confirm_transactions, :movable_transactions, :transactions]
  before_filter :set_two_column_head_layout, only: [:movable_transactions, :transactions]
  before_filter :store_fullpath_in_session, only: [:index, :show]

  load_and_authorize_resource :find_by => :url_name
  skip_load_and_authorize_resource :only => [:index, :show]

  # needed for transactions_with_search
  include TransactionSearch

  include FacilitiesHelper

  layout 'two_column'

  # GET /facilities
  def index
    @facilities = Facility.active
    @active_tab = 'home'
    render :layout => 'application'
  end

  # GET /facilities/abc123
  def show
    raise ActiveRecord::RecordNotFound unless current_facility && current_facility.is_active?
    @order_form = nil
    @order_form = Order.new if acting_user && current_facility.accepts_multi_add?
    @active_tab = 'home'
    render :layout => 'application'
  end

  # GET /facilities/list
  def list
    # show list of operable facilities for current user, and admins manage all facilities
    @active_tab = 'manage_facilites'
    if session_user.administrator?
      @facilities = Facility.all
      flash.now[:notice] = "No facilities have been added" if @facilities.empty?
    else
      @facilities = operable_facilities
      raise ActiveRecord::RecordNotFound if @facilities.empty?
      if (@facilities.size == 1)
        redirect_to facility_default_admin_path(@facilities.first)
        return
      end
    end

    render :layout => 'application'
  end

  # GET /facilities/1/manage
  def manage
    @active_tab = 'admin_facility'
  end

  # GET /facilities/new
  def new
    @active_tab = 'manage_facilites'
    @facility = Facility.new
    @facility.is_active = true

    render :layout => 'application'
  end

  # GET /facilities/1/edit
  def edit
    @active_tab = 'admin_facility'
  end

  # POST /facilities
  def create
    @active_tab = 'manage_facilites'
    @facility = Facility.new(params[:facility])

    if @facility.save
      flash[:notice] = 'The facility was successfully created.'
      redirect_to manage_facility_path(@facility)
    else
      render :action => "new", :layout => 'application'
    end
  end

  # PUT /facilities/abc123
  def update
    if current_facility.update_attributes(params[:facility])
      flash[:notice] = 'The facility was successfully updated.'
      redirect_to manage_facility_path(current_facility)
    else
      render :action => "edit"
    end
  end

  def schedule
    @active_tab = 'admin_products'
    render :layout => 'product'
  end

  def agenda
    @active_tab = 'admin_products'
    render :layout => 'product'
  end

  # GET /facilities/transactions
  def transactions_with_search
    paginate_order_details
  end

  # GET /facilities/1/movable_transactions
  def movable_transactions_with_search
    @order_details = @order_details.all_movable
    @order_detail_action = :reassign_chart_strings
    paginate_order_details 100
  end

  # POST /facilities/1/movable_transactions/reassign_chart_strings
  def reassign_chart_strings
    ensure_order_details_selected
    initialize_chart_string_reassignment_form
  end

  # POST /facilities/1/movable_transactions/confirm
  def confirm_transactions
    load_transactions
    initialize_chart_string_reassignment_form
  end

  # POST /facilities/1/movable_transactions/move
  def move_transactions
    begin
      reassign_account_from_params!
      bulk_reassignment_success
    rescue ActiveRecord::RecordInvalid => reassignment_error
      bulk_reassignment_failure(reassignment_error)
    end
    redirect_to facility_movable_transactions_path
  end

  def get_movable_transactions(account)
    @order_details.find_all do |order_detail|
      order_detail.can_be_assigned_to_account?(account)
    end
  end

  private

  def ensure_order_details_selected
    if @order_details.count < 1
      flash[:alert] = I18n.t('controllers.facilities.bulk_reassignment.no_transactions_selected')
      redirect_to facility_movable_transactions_path(params[:facility_id])
    end
  end

  def initialize_chart_string_reassignment_form
    @chart_string_reassignment_form = ChartStringReassignmentForm.new(@order_details)
    @date_range_field = 'journal_or_statement_date'
  end

  def load_order_details
    @order_details = OrderDetail.where(id: params[:order_detail_ids])
  end

  def load_transactions
    @selected_account = Account.find(params[:chart_string_reassignment_form][:account_id])
    @movable_transactions = get_movable_transactions(@selected_account)
    @unmovable_transactions = @order_details - @movable_transactions
  end

  def bulk_reassignment_success
    flash[:notice] = I18n.t('controllers.facilities.bulk_reassignment.move.success',
      count: @order_details.count)
  end

  def bulk_reassignment_failure(reassignment_error)
    flash[:alert] = I18n.t 'controllers.facilities.bulk_reassignment.move.failure',
      reassignment_error: reassignment_error,
      order_detail_id: reassignment_error.record.id
  end

  def reassign_account_from_params!
    account = Account.find(params[:account_id])
    OrderDetail.reassign_account!(account, @order_details)
  end

  def set_admin_billing_tab
    @active_tab = 'admin_billing'
  end

  def set_two_column_head_layout
    @layout = 'two_column_head'
  end
end
