module KamIRC
  module Box
    class Ping < Struct.new(:server, :server2)
      REGISTER['PING'] = self

      def self.from_message(msg)
        new(*msg[:params])
      end
    end

    def self.Ping(hash = {})
      Ping.new.tap do |instance|
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
