module KamIRC
  module Box
    class Join < Struct.new(:cmd, :channel, :target)
      REGISTER['JOIN'] = self

      def self.from_message(msg)
        new('JOIN', *msg[:params].map(&:to_s))
      end

      def to_message
        ":#{target} JOIN :#{channel}"
      end
    end

    def self.Join(hash = {})
      Join.new.tap do |instance|
        instance.cmd = 'JOIN'
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
