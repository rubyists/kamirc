module KamIRC
  module Box
    class Nick < Struct.new(:cmd, :nick)
      REGISTER['NICK'] = self

      def self.from_message(msg)
        new(msg[:cmd].to_s, *msg[:params].map(&:to_s))
      end
    end
  end
end

