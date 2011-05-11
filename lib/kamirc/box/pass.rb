module KamIRC
  module Box
    class Pass < Struct.new(:cmd, :password)
      REGISTER['PASS'] = self

      def self.from_message(msg)
        new('PASS', *msg[:params].map(&:to_s))
      end

      def to_message
        "PASS #{password}"
      end
    end

    def self.Pass(hash = {})
      Pass.new.tap do |instance|
        instance.cmd = 'PASS'
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
