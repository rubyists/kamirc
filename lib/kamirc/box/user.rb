module KamIRC
  module Box
    class User < Struct.new(:cmd, :nick, :flags, :reserved, :name)
      REGISTER['USER'] = self

      def self.from_message(msg)
        new(msg[:cmd].to_s, *msg[:params].map(&:to_s))
      end
    end
  end
end

