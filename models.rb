require 'bundler'
Bundler.setup
require 'mongoid'
require 'mongoid_paginate'
require 'carrierwave'
require 'carrierwave/mongoid'
require 'carrierwave/storage/sftp'
require 'digest/md5'
Mongoid.load! 'mongoid.yml', :production

class User
  include Mongoid::Document
  include Mongoid::Paginate

  paginate(per_page: 20)

  field :email, type: String
  field :password, type: String
  field :deadline, type: Date, default: -> { Date.today }
  field :traffic, type: Integer, default: 0
  field :used_traffic, type: Integer, default: 0
  field :token, type: String
  field :available, type: Boolean, default: false
  field :admin?, type: Boolean, default: false

  index({email: 1, token: 1})

  has_many :orders
  belongs_to :plan
  has_many :supports

  def auth?(pwd)
    self.password == pwd
  end

  def password=(pwd)
    super
    self.token = md5(email + md5(pwd))
  end

  def traffic_h
    human_traffic traffic
  end

  def used_traffic_h
    human_traffic used_traffic
  end

private
  def md5(str)
    Digest::MD5.hexdigest str
  end
  def human_traffic(t)
    units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB']
    i = 0
    t = t.to_f
    while t >= 1000.0
      t = t / 1000.0
      i = i + 1
    end
    sprintf("%.2f %s", t, units[i])
  end
end

class Order
  include Mongoid::Document
  include Mongoid::Timestamps

  field :_id, type: String, default: ->{ sprintf("%d%.4d", Time.now.to_i, Random.rand(10000)) }
  field :payment_status, type: String, default: ''
  field :price, type: Float
  field :month, type: Integer
  field :subject, type: String
  field :coupon, type: String

  index({_id: 1})

  belongs_to :user
  belongs_to :plan
end

class Plan
  include Mongoid::Document

  field :_id, type: Integer
  field :name, type: String
  field :price, type: Float
  field :traffic, type: Integer

  index({_id: 1})

  has_many :users
  has_many :orders
end

class Coupon
  include Mongoid::Document

  field :code, type: String
  field :discount, type: Float
  field :deadline, type: Date
end

class Server
  include Mongoid::Document

  field :server_name, type: String
  field :note, type: String
  field :normal?, type: Boolean, default: true
end

CarrierWave.configure do |config|
end

class SupportUploader < CarrierWave::Uploader::Base
  storage :sftp
  # root '/home/qinix/web/public'
  # asset_host "https://123feel.com"
  def extensions_white_list
    %w(jpg jpeg gif png)
  end

  def store_dir
    "uploads"
  end
end

class Support
  include Mongoid::Document

  belongs_to :user
  field :content, type: String
  field :email, type: String
  mount_uploader :image, SupportUploader
end

class Invite
  include Mongoid::Document

  belongs_to :inviter, class_name: "User"
  belongs_to :invited_user, class_name: "User"

  field :rewarded?, type: Boolean, default: false
  field :reward_days, type: Integer, default: 0
end

class PasswordReset
  include Mongoid::Document

  field :token, type: String, default: ->{ md5(rand_string() + Time.now.to_i.to_s ) }
  field :deadline, type: Time, default: ->{ Time.now + 86400 } # one day
  belongs_to :user

  def md5(str)
    Digest::MD5.hexdigest str
  end

  def rand_string
    o = [('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten
    string = (0...50).map{ o[rand(o.length)] }.join
  end
end

def available_check
  today = Date.today

  # available check
  User.each do |u|
    if u.deadline >= today and u.used_traffic <= u.traffic and u.available != true
      u.update_attribute(:available, true)
    elsif (u.deadline < today || u.used_traffic > u.traffic) && u.available != false
      u.update_attribute(:available, false)
    end
  end

end
