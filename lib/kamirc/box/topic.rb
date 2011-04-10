module KamIRC
  module Box
    class Topic < Struct.new(:cmd, :channel, :text)
      REGISTER['TOPIC'] = self

      def self.from_message(msg)
        new('TOPIC', *msg[:params].map(&:to_s))
      end

      def to_message
        "TOPIC #{channel} :#{text}"
      end
    end

    def self.Topic(hash = {})
      Topic.new.tap do |instance|
        instance.cmd = 'TOPIC'
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
