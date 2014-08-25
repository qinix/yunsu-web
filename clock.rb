$stdout.sync = true
require 'clockwork'
require './models'
require 'redis'
include Clockwork

$kv = Redis.new

configure do |config|
  config[:tz] = "Asia/Shanghai"
end

every 1.hour,  'hourly_check' do
  available_check
  password_reset_token_check
end

every 1.day, 'daily_check', at: "00:01" do # check it on 00:01 every day
  today = Date.today

  # coupon check
  Coupon.each do |c|
    if c.deadline < today
      c.destroy
    end
  end

  # daily_income_check
  $kv.set("daily_income", 0)

  # monthly income check
  if today.day == 1 # if today is the first day of this month
    $kv.set("income", 0)
    User.each do |u|
      u.update_attribute(:used_traffic, 0)
    end
  end
end

def password_reset_token_check
  PasswordReset.each do |pr|
    if Time.now > pr.deadline
      pr.destroy
    end
  end
end

def expire_check
  User.each do |u|
    check_user u, 7 #notify for 7 days before
  end
end

def check_user(user, before_days)
  today = Date.today
  if user.deadline == today + before_days
    Mailer.expire_notify(user.email, user.deadline).deliver
  end
end

Clockwork::run
