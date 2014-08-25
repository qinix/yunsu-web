require './models'

models = [User, Order, Plan, Coupon, KV]

models.each do |c|
	c.create_indexes
end
