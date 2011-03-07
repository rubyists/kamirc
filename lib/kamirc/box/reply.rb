module KamIRC
  module Box
    class Reply < Struct.new(:from, :cmd, :target, :params)
      def self.from_message(msg)
        from, cmd, params = msg.values_at(:prefix, :cmd, :params)
        target, params = params[0], params[1..-1]
        new(from, cmd, target, params)
      end
    end
  end
end
