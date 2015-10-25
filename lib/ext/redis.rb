module Snapstats

  def self.redis
    @@redis ||= nil # ||= Redis.new(:host => 'localhost', :port => 6379)
  end

  def self.set_redis opt={}
    @@redis = Redis.new( opt.present? ? opt : { :host => 'localhost', :port => 6379 } )
  end

  def self.mkey name
    "snaps:#{name}"
  end

  def self.mtime name
    "snaps:#{Time.now.to_i}:#{name}"
  end

  def self.mday name
    "snaps:#{DateTime.current.beginning_of_day.to_i}:#{name}"
  end

end
