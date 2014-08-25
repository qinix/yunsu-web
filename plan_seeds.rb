require './models'

Plan.destroy_all
plan = []
(0..3).each do |n|
	plan[n] = Plan.new
	plan[n][:_id] = n
end
plan[0].name = ''
plan[0].price = 0.0
plan[0].traffic = 0

plan[1].name = '标准套餐'
plan[1].price = 10.0
plan[1].traffic = 10_000_000_000

plan[2].name = '高级套餐'
plan[2].price = 15.0
plan[2].traffic = 25_000_000_000

plan[3].name = '终极套餐'
plan[3].price = 25.0
plan[3].traffic = 50_000_000_000

plan.each do |p|
	p.save
end
