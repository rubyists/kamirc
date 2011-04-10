module KamIRC
  module Box
    class Pong < Struct.new(:cmd, :server, :server2)
      REGISTER['PONG'] = self

      def self.from_message(msg)
        new("PONG", *msg[:params].map(&:to_s))
      end

      def to_message
        servers = [server, server2].compact.join(" ")
        "PONG #{servers}"
      end
    end

    def self.Pong(hash = {})
      Pong.new.tap do |instance|
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
