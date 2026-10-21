# Sends micro clusters back to a stage, e.g. after a policy change or when the
# owner asks for more research. Their results in that stage and all later ones
# are moved to RUN_DIR/redone/ (kept for reference); next.rb then hands them out
# again.
#
#   ruby redo.rb RUN_DIR STAGE ID...
#
# IDs are micro cluster ids, or merge pair ids ("m<low>-<high>") for the merge
# stage.
require_relative "lib/common"

dir = IgnoredInksReview.run_dir(ARGV[0])
stage = ARGV[1]
usage =
  "Usage: redo.rb RUN_DIR #{IgnoredInksReview::STAGES.join("|")} ID... (micro cluster ids or m<low>-<high>)"
ids =
  ARGV[2..].to_a.map do |arg|
    next arg if arg.match?(/\Am\d+-\d+\z/)

    Integer(arg, 10)
  rescue ArgumentError
    abort usage
  end
abort usage unless IgnoredInksReview::STAGES.include?(stage) && ids.any?

redone = Hash.new { |h, k| h[k] = [] }
IgnoredInksReview::STAGES
  .drop(IgnoredInksReview::STAGES.index(stage))
  .each do |later_stage|
    IgnoredInksReview
      .batch_files(dir, later_stage)
      .each do |input|
        output = IgnoredInksReview.output_for(input)
        next unless File.exist?(output)

        rows = IgnoredInksReview.read_json(output)
        removed, kept = rows.partition { |row| ids.include?(row["id"]) }
        next if removed.empty?

        archive =
          File.join(
            dir,
            "redone",
            "#{later_stage}-#{File.basename(output, ".json")}-#{Time.now.strftime("%Y%m%d%H%M%S")}.json"
          )
        IgnoredInksReview.write_json(archive, removed)
        IgnoredInksReview.write_json(output, kept)
        removed.each { |row| redone[later_stage] << row["id"] }
      end
  end

puts JSON.pretty_generate("redone" => redone)
