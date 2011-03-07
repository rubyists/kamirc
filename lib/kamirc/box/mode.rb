module KamIRC
  module Box
    class Mode < Struct.new(:from, :cmd, :target, :mode)
      REGISTER['MODE'] = self

      def self.from_message(msg)
        new(msg[:prefix], 'MODE', *msg[:params])
      end
    end
  end
end

