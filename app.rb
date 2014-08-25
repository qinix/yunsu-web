# encoding: utf-8
$stdout.sync = true
require 'bundler'
Bundler.require
require './models'
require './mailer'

set :sessions, true
set :server, :Puma
use Rack::Session::Cookie, secret: 'fjkdlsfneiovnsa;jdsa;jfwefjdskfejkwncjkxz'
use Rack::Flash
register Mongoid::Paginate::Sinatra

Alipay.pid = ''
Alipay.key = ''
Alipay.seller_email = 'i@qinix.com'

$kv = Redis.new

helpers do
  def login_required
    user = current_user
    if user
      return true
    else
      session[:return_to] = request.fullpath
      redirect '/login'
      return false
    end
  end

  def admin_required
    user = current_user
    if user && user[:admin?]
      return true
    else
      session[:return_to] = request.fullpath
      redirect '/login'
      return false
    end
  end

  def admin?
    !!current_user && current_user.admin?
  end

  def current_user
    if session[:user]
      User.where(_id: session[:user]).first
    else
      nil
    end
  end

  def logged_in?
    !!session[:user]
  end

  def make_payment(order)
    hostname = 'http://yunsu-web.herokuapp.com'
    coupon = Coupon.where(code: order.coupon).first
    if coupon
      order.price = make_price(order.price * coupon.discount)
      order.save
    end
    get_money = make_price(order.price * 0.988)
    royalty = "i@qinix.com^#{sprintf("%.2f", get_money)}^yunsu"
    options = {
      :out_trade_no      => order[:_id].to_s,
      :subject           => order.subject,
      :logistics_type    => 'DIRECT',
      :logistics_fee     => '0',
      :logistics_payment => 'SELLER_PAY',
      :total_fee         => sprintf("%.2f", order.price),
      # :price            => sprintf("%.2f", order.price),
      # :quantity         => 1,
      :royalty_type      => "10",
      :royalty_parameters => royalty,
      :return_url        => "#{hostname}/user/pay_success/#{order.id}",
      :notify_url        => "#{hostname}/alipay_notify"
    }

    Alipay::Service.create_direct_pay_by_user_url(options)
  end

  def make_price(p)
    sprintf("%.2f", p).to_f
  end
end

before do
  if params["r"]
    session[:r] = params["r"]
  end
end

before '/admin/?*' do
  admin_required
  @admin_space = true
end

before '/user/?*' do
  login_required
  @user_space = true
end

get '/' do
  erb :index
end

get '/plan' do
  erb :plan
end

get '/faq' do
  erb :faq
end

get '/login' do
  erb :login
end

get '/status' do
  @normal = true
  Server.each do |s|
    if s[:normal?] == false
      @normal = false
    end
  end
  erb :status
end

get '/login' do
  erb :login
end

post '/login' do
  email = params["email"]
  password = params["password"]
  user = User.where(email: email).first
  if user.respond_to?(:auth?) && user.auth?(password)
    session[:user] = user[:_id]
    if session[:return_to]
      redirect session[:return_to]
    else
      redirect '/user'
    end
  else
    flash[:error] = '用户名或密码错误，请重新输入'
    redirect '/login'
  end
end

get '/logout' do
  session[:user] = nil
  redirect '/'
end

get '/signup' do
  erb :signup
end

post '/signup' do
  email = params["email"]
  password = params["password"]
  password_confirm = params["password_confirm"]
  affed_by_user = session[:r]
  if email == ""
    flash[:error] = "邮箱不可为空"
    redirect '/signup'
  end
  if password != password_confirm
    flash[:error] = "密码不一致"
    redirect '/signup'
  end
  if password == ""
    flash[:error] = "密码不可为空"
    redirect '/signup'
  end
  if User.where(email: email).first.respond_to?(:auth?)
    flash[:error] = "邮箱已被使用"
    redirect '/signup'
  end
  user = User.new
  user.email = email
  user.password = password
  user.plan_id = 0
  user.save
  if affed_by_user
    invite = Invite.new
    invite.inviter = User.where(_id: affed_by_user).first
    invite.invited_user = user
    invite.save
  end
  Mailer.register(user.email).deliver
  session[:user] = user[:_id]
  redirect '/user'
end

get '/forget_pass' do
  erb :forget_pass
end

post '/forget_pass' do
  ps = PasswordReset.new
  user = User.where(email: params["email"]).first
  if user.nil?
    flash[:error] = "这个邮箱地址不存在，请核对后输入"
    redirect '/forget_pass'
  else
    flash[:success] = "一封包含重置密码链接的邮件已发送到您的邮箱,请查收"
  end
  ps.user = user
  ps.save
  Mailer.password_reset(user.email, "http://yunsu-web.herokuapp.com/reset_password/#{ps.token}").deliver
  redirect '/forget_pass'
end

get '/reset_password/:token' do
  ps = PasswordReset.where(token: params[:token]).first
  if ps.nil? or Time.now > ps.deadline
    flash[:error] = "重置密码链接已超时"
    redirect '/login'
  end
  erb :reset_password
end

post '/reset_password/:token' do
  ps = PasswordReset.where(token: params[:token]).first
  if ps.nil? or Time.now > ps.deadline
    flash[:error] = "重置密码链接已超时"
    redirect '/login'
  end
  user = ps.user
  password = params["password"]
  user.password = password
  ps.destroy
  user.save
  flash[:success] = "密码重置成功"
  redirect '/login'
end

get '/user/?' do
  @title = "用户账户"
  @user = current_user
  noplan = Plan.where(_id: 0).first
  @has_plan = if @user.plan == noplan then false else true end
  erb :user
end

get '/user/tutorial' do
  user = current_user
  if user.plan_id == 0
    @buyed = false
  else
    @buyed = true
  end
  erb :user_tutorial
end

get '/user/settings' do
  erb :user_settings
end

post '/user/settings' do
  newpwd = params["newpwd"]
  newpwd_again = params["newpwd-again"]
  if newpwd != newpwd_again
    flash[:error] = '两次输入的密码不相同'
  elsif newpwd == current_user.password
    flash[:error] = "与原密码相同"
  else
    user = current_user
    user.password = newpwd
    user.save
    Mailer.password_modify(user.email).deliver
    flash[:success] = '密码修改成功'
  end
  redirect '/user/settings'
end

get '/user/aff' do
  user = current_user
  @invites = Invite.where(inviter: user).to_a.select {|i| i[:reward_days] > 0}
  @aff_days = 0
  @invites.each do |i|
    @aff_days += i[:reward_days]
  end

  erb :user_aff
end

get '/user/support' do
  erb :user_support
end

post '/user/support' do
  support = Support.new
  user = current_user
  user.supports << support
  support.email = params["email"]
  support.image = params["uni_file"]
  support.content = params["content"]
  support.save
  user.save
  flash[:success] = "提交成功"
  Mailer.support_mail("i@qinix.com", support).deliver
  redirect '/user/support'
end

get '/user/buy/:plan_id' do
  user = current_user
  plan_id = params[:plan_id].to_i
  plan = Plan.where(_id: plan_id).first
  if user.plan_id == plan_id or user.plan_id == 0# 续费 & 购买
    time = params["time"]
    pay_month, @month = if time == '1mo' then [1, 1] elsif time == '3mo' then [3, 3] elsif time == '1ye' then [10, 12] else [0, 0] end
    @price = plan.price * pay_month
    @subject = plan.name
    erb :buy #post
  elsif user.plan_id < plan_id # 升级
    days = (user.deadline - Date.today).to_i
    delta_price = plan.price - user.plan.price
    @month = days.to_f / 30.to_f
    @price = make_price(delta_price * @month)
    @subject = "升级 - #{plan.name}"
    erb :buy #post
  elsif user.plan_id > plan_id # 降级
    days = (user.deadline - Date.today).to_i
    @month = days.to_f / 30.to_f
    @price = 0.00
    @subject = "降级 - #{plan.name}"
    erb :demotion
  end
end

post '/user/buy/:plan_id' do
  plan_id = params[:plan_id].to_i
  plan = Plan.where(_id: plan_id).first
  noplan = Plan.where(_id: 0).first
  user = current_user
  if user.plan_id == plan_id or user.plan_id == 0# 续费 & 购买
    order = Order.new
    order.plan = plan
    time = params["time"]
    order.coupon = params["coupon"]
    if order.coupon != ""
      coupon = Coupon.where(code: order.coupon).first
      if coupon.nil?
        flash[:error] = "优惠码错误"
        redirect env["REQUEST_URI"]
      end
    end
    pay_month, order.month = if time == '1mo' then [1, 1] elsif time == '3mo' then [3, 3] elsif time == '1ye' then [10, 12] else [0, 0] end
    order.price = make_price(plan.price * pay_month)
    order.subject = "#{order.month} 月-#{order.plan.name}"
    user.orders << order
    order.save
    user.save
    redirect make_payment(order)
  elsif user.plan_id > plan_id # 降级
    user.plan = plan
    user.traffic = plan.traffic
    user.save
    redirect '/user'

  elsif user.plan_id < plan_id # 升级
    order = Order.new
    order.plan = plan
    order.coupon = params["coupon"]
    if order.coupon != ""
      coupon = Coupon.where(code: order.coupon).first
      if coupon.nil?
        flash[:error] = "优惠码错误"
        redirect request.path
      end
    end
    order.subject = "升级 - #{plan.name}"
    days = (user.deadline - Date.today).to_i
    delta_price = plan.price - user.plan.price
    months = days.to_f / 30.to_f
    order.price = make_price(delta_price * months)
    order.month = 0
    user.orders << order
    order.save
    user.save
    redirect make_payment(order)
  end
end

get '/user/pay_success/:order_id' do
  flash[:success] = "您的套餐已生效，以下是您的套餐详情"
  redirect '/user'
end

get '/admin/?' do
  @user_count = User.count
  @daily_income = make_price($kv.get("daily_income").to_f * 0.01)
  @income = make_price($kv.get("income").to_f * 0.01)
  @expense = make_price($kv.get("expense").to_f * 0.01)
  erb :adm
end

get '/admin/server' do
  @servers = Server.all
  erb :adm_server
end

get '/admin/product' do
  @coupons = Coupon.all
  erb :adm_product
end

get '/admin/coupon/:coupon_id/delete' do
  c = Coupon.where(code: params[:coupon_id]).first
  c.destroy
  redirect '/admin/product'
end

post '/admin/product' do
  c = Coupon.new
  c.code = params["coupon"]
  c.discount = params["discount"].to_f / 10.0
  deadline = params["deadline"].split '-'
  deadline.collect! {|d| d.to_i}
  c.deadline = Date.new(2000 + deadline[0], deadline[1], deadline[2])
  c.save
  redirect '/admin/product'
end

get '/admin/user/?' do
  @users = User.paginate(params["page"] || 1)
  erb :adm_user
end

post '/admin/user/?' do
  if params["search"]
    user = User.where(email: params["search"]).first
    if user.nil?
      flash[:error] = "无此用户"
      redirect env["REQUEST_URI"]
    end
    redirect "/admin/user/#{user.id}"
  end
  redirect env["REQUEST_URI"]
end

get '/admin/user/:user_id' do
  @u = User.where(_id: params[:user_id]).first
  if not @u
    flash[:error] = "无此用户"
    redirect '/admin/user'
  end
  erb :adm_user_manage
end

post '/admin/user/:user_id' do
  @u = User.where(_id: params[:user_id]).first
  pd = params["deadline"].split '-'
  year = pd[0].to_i
  month = pd[1].to_i
  day = pd[2].to_i
  @u.deadline = Date.new(year, month, day)
  plan = Plan.where(id: params["plan"].to_i).first
  @u.plan = plan
  @u.traffic = plan.traffic
  @u.save

  redirect "/admin/user/#{params[:user_id]}"

end

post '/alipay_notify' do
  order = Order.where(_id: params["out_trade_no"]).first
  before_status = order.payment_status
  order.payment_status = params["trade_status"]
  order.save
  if before_status == ''
    user = order.user
    user.plan = order.plan
    user.deadline = user.deadline >> order.month
    user.traffic = order.plan.traffic
    user.available = true
    invite = Invite.where(invited_user: user).first
    if invite and not invite[:rewarded?]
      invite.reward_days = if order.month == 1 then 7 elsif order.month == 3 then 21 elsif order.month == 12 then 30 else 0 end
      inviter = invite.inviter
      inviter.deadline += invite.reward_days
      inviter.save
      invite[:rewarded?] = true
      invite.save
      Mailer.aff_user(inviter.email, invite).deliver
    end
    user.save
    income = make_price(order.price * 0.988)
    $kv.incrby("income", (income.to_f * 100).to_i)
    $kv.incrby("daily_income", (income.to_f * 100).to_i)
    Mailer.buy_success(user.email, user.plan.name, user.traffic_h, user.deadline).deliver
  end
  'success'
end

get '/api/servers' do
  servers = []
  Server.each do |s|
    servers << "#{s.server_name}|#{s.note}"
  end
  servers.join "\n"
end

get '/api/auth' do
  email = params['username']
  password = params['password']
  user = User.where(email: email).first
  if not user.nil? and user.auth?(password)
    res = { 'authorized' => true }
  else
    res = { 'authorized' => false }
  end
  res.to_json
end

get '/about' do
  erb :about
end
