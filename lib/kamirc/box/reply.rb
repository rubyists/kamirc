module KamIRC
  module Box
    class Reply < Struct.new(:from, :cmd, :target, :params)
      def self.from_message(msg)
        from, cmd, params = msg.values_at(:prefix, :cmd, :params)
        target, params = params[0], params[1..-1]
        new(from, cmd, target, params)
      end

      def inspect
        "%s %p -> %s : %p" % [from, cmd, target, params]
      end

      def to_message
        p self
        ":#{from[:hostname]} #{cmd} #{target} :#{params.join(' ')}"
      end
    end

    def self.Reply(hash = {})
      Reply.new.tap do |instance|
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
