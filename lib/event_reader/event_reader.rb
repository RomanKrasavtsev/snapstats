module Snapstats
  module EventReader
    require "event_reader/event_reader_helpers"

    class Common
      def self.fetch_avalible_months
        Snapstats.redis.keys("snaps:*").map{ |i| DateTime.strptime(i.split(":")[1], "%s") }.map{ |i| i.month }.sort.uniq
      end
    end

    class Top
      include Virtus.model
      extend EventReaderHelpers

      attribute :name, String
      attribute :total, Integer

      def self.fetch key
        ret = Snapstats.redis.zrevrangebyscore Snapstats.mday(key), "+inf", "-inf", :with_scores => true, limit: 10
        ret.map { |i| self.new(name: i.first, total: i.last) }
      end

      def self.fetch_pathes
        fetch("top:pathes")
      end

      def self.fetch_browsers
        fetch("top:browsers").map{|i| i.name = i.name.split("|").last.strip; i }
      end

      def self.fetch_devices
        fetch("top:devices").map{|i| i.name = i.name.split("|").last.strip; i }
      end
    end

    class Activity
      include Virtus.model
      extend EventReaderHelpers

      attribute :email, String
      attribute :path, String
      attribute :controller, String
      attribute :action, String
      attribute :runtimes, Hash
      attribute :os, String
      attribute :browser, String
      attribute :version, String
      attribute :ip, String
      attribute :render_time, String
      attribute :date, Time

      def self.fetch from=0, to=Time.now
        Snapstats.redis.zrangebyscore(Snapstats.mday("activity"), from.to_i, to.to_i).map do |i|
          v = JSON.parse(i, :symbolize_names => true)

          self.new(email:       v[:email],
                   path:        v[:path],
                   controller:  v[:ctrl],
                   action:      v[:actn],
                   runtimes:    v[:rntm],
                   os:          v[:os],
                   browser:       v[:brwsr],
                   version:       v[:brver],
                   ip:          v[:ip],
                   render_time:   v[:total],
                   date:        Time.at(v[:date].to_i))
        end
      end

      def self.fetch_all_chart

        # after 5 minutes i forgot how it works

        fetch(Time.now.beginning_of_day).map{ |i|

          i.runtimes.reduce({}){ |sum, (k,v)| sum[k] = { value: v, date: i.date.to_i }; sum }

        }.reduce({}){ |sum, i|

          i.keys.each{ |rt| sum[rt].present? ? sum[rt] << i[rt] : sum[rt] = [ i[rt] ] }
          sum
        }
      end

      def self.fetch_all_chart_scale aprx=5
        charts = fetch_all_chart

        charts.keys.each { |runtime|
          charts[runtime] = charts[runtime].group_by{ |i| floor_time(i[:date].to_i, aprx.minutes) }.map{|k,v| { :date => k, :value => v.max_by{|i| i[:value]}[:value] }}
        }

        charts
      end

      def self.fetch_flat_chart aprx=5
        fetch(Time.now.beginning_of_day).group_by{ |i| floor_time(i[:date].to_i, aprx.minutes) }.map{|k,v| { :date => k, :value => v.max_by{|i| i.render_time.to_f }.render_time }}#.map{ |i| { date: i.date.to_i, value: i.render_time } }
      end

    end

    class Performance
      include Virtus.model

      attribute :controller
      attribute :action
      attribute :render_time

      def self.fetch_slowest_controllers
        Snapstats.redis.zrevrangebyscore(Snapstats.mday('performance:controllers'), '+inf', '-inf', { withscores: true }).map do |i|
          v     = JSON.parse(i.first, :symbolize_names => true)
          time  = i.last

          self.new(controller: v[:ctrl], action: v[:actn], render_time: time)
        end
      end

    end

    class Browsers
      include Virtus.model

      attribute :name, String
      attribute :total, Integer

      def self.fetch_platforms
        data = Snapstats.redis.hgetall(Snapstats.mday("platforms")).values.group_by{ |platform| platform }.map{ |name, platforms|{name => platforms.count} }
        data.map{|i| self.new(name: (i.keys.try(:first).present? ? i.keys.try(:first) : 'Other'), total: i.values.try(:first)) }
      end

      def self.fetch_browsers
        data = Snapstats.redis.hgetall(Snapstats.mday("browsers")).values.group_by{ |browser| browser }.map{ |name, browsers|{ name => browsers.count} }
        data.map{|i| self.new(name: i.keys.try(:first), total: i.values.try(:first) ) }
      end
    end

    class Uniqs
      include Virtus.model

      def self.fetch_uniqs
        Snapstats.redis.hlen(Snapstats.mday("uniq_client_ids")).to_i
      end
    end

    class Cpm
      include Virtus.model
      extend EventReaderHelpers

      def self.fetch_all
        Snapstats.redis.hgetall(Snapstats.mday("cpm"))
      end

      def self.fetch_all_hash
        data = Snapstats.redis.hgetall(Snapstats.mday("cpm"))

        cpm = data[Time.now.beginning_of_minute.to_i.to_s] || 0
        cpd = data.values.reduce(0){ |sum, i| sum + i.to_i }

        # cph = data.group_by{ |k, v| Time.at(k.to_i).beginning_of_hour }.reduce({}){|sum, (k, v)| sum[k] = v.map{|i| i.last.to_i}.reduce(:+); sum }
        # cph = cph.values.reduce(:+) / cph.keys.count

        { cpm: cpm, cph: 0, cpd: cpd }
      end

      def self.fetch_all_chart aprx=10
        fetch_all.group_by{|k, v| floor_time(k.to_i, aprx.minutes) }.reduce({}){ |sum, (k,v)| sum[k] = v.reduce(0){|s, i| s += i.last.to_i }; sum }.map{ |k, v| { date: k, value: v } }
      end

    end

    class UserActivity
      include Virtus.model
      extend EventReaderHelpers

      attribute :email, String
      attribute :date, Time
      attribute :path, String
      attribute :user_id, String
      attribute :render_time, String
      attribute :os, String
      attribute :browser, String
      attribute :version, String

      def self.fetch_all
        Snapstats.redis.hgetall(Snapstats.mday("activity:users")).map do |uid, values|
          values = JSON.parse(values, :symbolize_names => true)
          self.new(email: values[:email], date: Time.at(values[:ts].to_i), path: values[:path], user_id: uid)
        end
      end

      def self.fetch_for_user user_id, from='+inf', to='-inf'
        Snapstats.redis.zrevrangebyscore(Snapstats.mday("activity:user:#{user_id}"), from, to).map do |i|
          v = JSON.parse(i, :symbolize_names => true)

          self.new( path:         v[:path],
                    render_time:  v[:total],
                    os:           v[:os],
                    browser:      v[:brwsr],
                    version:      v[:brver],
                    date:         Time.at(v[:ts].to_i))
        end
      end

      def self.fetch_email_by_uid user_id
        data = Snapstats.redis.hgetall(Snapstats.mday("activity:users"))[user_id]
        JSON.parse(data, :symbolize_names => true)[:email] if data
      end

      def self.fetch_chart_for_user user_id, aprx=10
        fetch_for_user(user_id).group_by{ |i| floor_time(i.date.to_i, aprx.minutes) }.map{ |k, v| { date: k.to_i, value: v.count } }
      end

    end

  end
end
