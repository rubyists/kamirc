module KamIRC
  module Box
    class Part < Struct.new(:cmd, :channel, :text, :target)
      REGISTER['PART'] = self

      def self.from_message(msg)
        new('PART', *msg[:params].map(&:to_s))
      end

      def to_message
        ":#{target} PART :#{channel}"
      end
    end

    def self.Part(hash = {})
      Part.new.tap do |instance|
        instance.cmd = 'PART'
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
