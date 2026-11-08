module Bench
  module Clusterer
    class Source < ActiveRecord::Base
      self.abstract_class = true

      def self.connect(url)
        establish_connection(url) if url.present?
        self
      end

      def self.rows(sql, binds = {})
        connection.select_all(sanitize_sql_array([sql, binds])).to_a
      end
    end
  end
end
