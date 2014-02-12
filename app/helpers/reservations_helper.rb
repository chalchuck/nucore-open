module ReservationsHelper
  def add_accessories_link(reservation)
    if reservation.order_detail.accessories? && reservation.reserve_end_at < Time.zone.now
      link_to t('product_accessories.pick_accessories.link'), reservation_pick_accessories_path(reservation), :class => 'has_accessories persistent'
    end
  end

  def reservation_pick_accessories_path(reservation)
    new_order_order_detail_accessory_path(reservation.order_detail.order, reservation.order_detail)
  end

  def end_reservation_class(reservation)
    reservation.order_detail.accessories? ? :has_accessories : nil
  end

  def reservation_actions(reservation)
    ReservationUserActionPresenter.new(self, reservation).user_actions
  end

  def reservation_view_edit_link(reservation)
    ReservationUserActionPresenter.new(self, reservation).view_edit_link
  end
end
