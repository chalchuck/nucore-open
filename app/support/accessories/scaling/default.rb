class Accessories::Scaling::Default
  attr_accessor :enabled, :order_detail

  # We need to respond_to? these as opposed to sending them to method_missing
  delegate :to_s, :to_param, :errors, :to => :order_detail

  def initialize(order_detail)
    @order_detail = order_detail
  end

  def update_quantity
    @order_detail.quantity ||= 1
  end

  def quantity_editable?
    true
  end

  def quantity_as_time?
    false
  end

  def enabled?
    !!@enabled
  end

  def assign_attributes(attrs)
    self.enabled = attrs.delete :enabled if attrs[:enabled]
    @order_detail.assign_attributes(attrs)
  end

  # Since this is a decorator, allow comparison with the base OrderDetail
  def ==(other)
    if other.is_a? OrderDetail
      @order_detail == other
    else
      self.equal? other
    end
  end

  private

  def method_missing(method, *args)
    @order_detail.send(method, *args)
  end
end
