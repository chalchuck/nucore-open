# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Major.create(:name => 'Daley', :city => cities.first)

OrderStatus.create(name: 'New')
OrderStatus.create(name: 'In Process')
OrderStatus.create(name: 'Canceled')
OrderStatus.create(name: 'Complete')
OrderStatus.create(name: 'Reconciled')

Affiliate.find_or_create_by_name('Other')

[
  PriceGroup.new(name: Settings.price_group.name.base, is_internal: true, admin_editable: false),
  PriceGroup.new(name: Settings.price_group.name.cancer_center, is_internal: true, admin_editable: true),
  PriceGroup.new(name: Settings.price_group.name.external, is_internal: false, admin_editable: false)
].each_with_index do |price_group, index|
  price_group.display_order = index + 1
  price_group.save(validate: false)
end
