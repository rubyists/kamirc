module KamIRC
  module Box
    # Command: MODE
    # Parameters: <channel> *( ( "-" / "+" ) *<modes> *<modeparams> )
    class Mode < Struct.new(:from, :cmd, :target, :mode)
      REGISTER['MODE'] = self

      def self.from_message(msg)
        new(msg[:prefix], 'MODE', *msg[:params].map(&:to_s))
      end
    end
  end
end

