# Maps revdiff annotations on the review files back to micro cluster ids and
# their current decisions, so they can be turned into overrides.json entries.
#
#   ruby annotations.rb RUN_DIR ANNOTATIONS_FILE
#
# ANNOTATIONS_FILE is revdiff's output: "## file:line (type)" headers, each
# followed by the annotation text.
require_relative "lib/common"

dir = IgnoredInksReview.run_dir(ARGV[0])
annotations_file = ARGV[1] or abort "Usage: annotations.rb RUN_DIR ANNOTATIONS_FILE"

line_map = IgnoredInksReview.read_json(File.join(dir, "review", "line-map.json"))
data = IgnoredInksReview.read_json(File.join(dir, "decisions.json"))
decisions = data["decisions"].to_h { |d| [d["id"], d] }
merges = (data["merges"] || []).to_h { |m| [m["id"], m] }

annotations = []
File
  .read(annotations_file)
  .each_line do |line|
    if (
         match =
           line.match(/\A## (?<file>[^:\n]+?)(?::(?<line>\d+)(?:-\d+)?)? \((?<type>[^)]*)\)\s*\z/)
       )
      annotations << {
        "file" => File.basename(match[:file]),
        "line" => match[:line]&.to_i,
        "text" => +""
      }
    elsif annotations.any?
      annotations.last["text"] << line
    end
  end

result =
  annotations.map do |annotation|
    entry =
      line_map.find do |m|
        m["file"] == annotation["file"] && annotation["line"] &&
          annotation["line"].between?(m["from"], m["to"])
      end
    ids = entry ? entry["ids"] : []
    {
      "file" => annotation["file"],
      "line" => annotation["line"],
      "annotation" => annotation["text"].strip,
      "ids" => ids,
      "current" =>
        ids.map do |id|
          if merges.key?(id)
            merges[id].slice("id", "verdict", "from", "into")
          else
            decisions[id].slice(
              "id",
              "name",
              "verdict",
              "cluster_id",
              "group",
              "proposed_verdict",
              "users"
            )
          end
        end
    }
  end

puts JSON.pretty_generate(result)
