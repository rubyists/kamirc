module KamIRC
  module Box
    class Quit < Struct.new(:cmd, :message, :target)
      REGISTER['QUIT'] = self

      def self.from_message(msg)
        new("QUIT", *msg[:params].map(&:to_s))
      end

      def to_message
        ":#{target} QUIT :#{message}"
      end
    end

    def self.Quit(hash = {})
      Quit.new.tap do |instance|
        instance.cmd = 'QUIT'
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
