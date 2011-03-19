module KamIRC
  module Box
    class Pong < Struct.new(:cmd)
      REGISTER['PONG'] = self

      def self.from_message(msg)
        new(msg[:cmd].to_s)
      end

      def to_message
        "PONG"
      end
    end

    def self.Pong(hash = {})
      Pong.new.tap do |instance|
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
