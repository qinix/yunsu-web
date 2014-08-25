# encoding: utf-8
require 'action_mailer'

ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
   :address   => "smtp.gmail.com",
   :port      => 587,
   :domain    => "qinix.com",
   :authentication => :plain,
   :user_name      => "",
   :password       => "",
   :enable_starttls_auto => true
  }
ActionMailer::Base.view_paths = 'views'

class Mailer < ActionMailer::Base
  default from: "i@qinix.com"

  def password_reset(to, reset_link)
    @reset_link = reset_link
    mail(to: to, subject: "云速 - 重置密码") do |format|
                format.html
    end
  end

  def aff_user(to, invite)
    @invite = invite

    mail(to: to, subject: "云速 - 邀请用户奖励") do |format|
                format.html
    end
  end

  def register(to)
    @email = to

    mail(to: to, subject: "云速 - 注册成功") do |format|
                format.html
    end
  end

  def buy_success(to, plan_name, traffic, deadline)
    @plan_name = plan_name
    @traffic = traffic
    @deadline = deadline

    mail(to: to, subject: "云速 - 购买成功") do |format|
                format.html
    end
  end

  def expire_notify(to, deadline)
    @deadline = deadline

    mail(to: to, subject: "云速 - 到期提醒") do |format|
                format.html
    end
  end

  def password_modify(to)
    mail(to: to, subject: "云速 - 修改密码") do |format|
                format.html
    end
  end

  def support_mail(to, support)
    @email = support.email
    @content = support.content
    @img = support.image.url

    mail(to: to, subject: "来自#{@email}的工单 - 云速") do |format|
                format.html
    end
  end
end
