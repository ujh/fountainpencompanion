# Runs one read-only SQL statement from stdin and prints the rows as TSV.
#
#   ruby query.rb <<'SQL'
#   select id, brand_name, ink_name from macro_clusters where ink_name ilike '%yoi%';
#   SQL
require_relative "lib/common"

sql = $stdin.read
abort "No SQL on stdin" if sql.strip.empty?

result = IgnoredInksReview.connection.exec(sql)
puts result.fields.join("\t")
result.each_row { |row| puts row.map { |value| value.to_s.gsub(/[\t\n\r]/, " ") }.join("\t") }
