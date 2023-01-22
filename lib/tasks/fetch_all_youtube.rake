task :fetch_all_youtube, [:channel_id] => :environment do |task, args|
  channel_id = args[:channel_id]
  youtube = Youtube.new(channel_id: channel_id)
  puts "Fetching #{youtube.channel_name}"
  youtube.fetch_videos.each do |video|
    video = postprocess(video)
    submit_video(video)
    sleep((rand * 3).seconds)
  end
end

private

def submit_video(video)
  return unless video[:macro_cluster]
  sub =
    CreateInkReviewSubmission.new(
      url: video[:url],
      user: User.first,
      macro_cluster: video[:macro_cluster]
    ).perform
end

def postprocess(video)
  search_term = video[:title]
  cluster = MacroCluster.full_text_search(search_term).first
  v = video.merge(macro_cluster: cluster)
  pp v
  v
end
