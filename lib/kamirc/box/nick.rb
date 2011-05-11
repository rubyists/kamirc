module KamIRC
  module Box
    class Nick < Struct.new(:cmd, :nick)
      REGISTER['NICK'] = self

      def self.from_message(msg)
        new('NICK', *msg[:params].map(&:to_s))
      end

      def to_message
        "NICK #{nick}"
      end
    end

    def self.Nick(hash = {})
      Nick.new.tap do |instance|
        instance.cmd = 'NICK'
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
