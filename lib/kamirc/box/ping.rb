module KamIRC
  module Box
    class Ping < Struct.new(:cmd, :server, :server2)
      REGISTER['PING'] = self

      def self.from_message(msg)
        new('PING', *msg[:params].map(&:to_s))
      end

      def to_message
        servers = [server, server2].compact.join(" ")
        "PING :#{servers}"
      end
    end

    def self.Ping(hash = {})
      Ping.new.tap do |instance|
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
