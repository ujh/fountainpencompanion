print %(v#{`git tag`.split.map {|v| v.gsub('v','').to_i }.sort.last.succ})
