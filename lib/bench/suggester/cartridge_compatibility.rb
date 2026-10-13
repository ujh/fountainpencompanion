module Bench
  module Suggester
    module CartridgeCompatibility
      CARTRIDGE_FILLING =
        %r{\bc\s*/\s*c\b|\bcc\b|convert|cartridge|internation|\bstandard\s+(?:short|long)\b}i

      def self.compatible?(pen, ink)
        return true unless ink.kind == "cartridge"

        filling = pen.filling_system.to_s.strip
        filling.empty? || filling.match?(CARTRIDGE_FILLING)
      end
    end
  end
end
