task fetch_all_youtube: :environment do
  channels.each do |channel|
    youtube = Youtube.new(channel)
    puts "Fetching #{youtube.channel_name}"
    youtube.fetch_videos.each do |video|
      video = postprocess(video)
      submit_video(video)
      sleep((rand*3).seconds)
    end
  end
end

private

def channels
  [
    {channel_id: 'UCruW1x5gCc21b0khnEzrOgg'}, # Mick L
    {channel_id: 'UCZaWG7RkmQVLE0EmvfOuJ9w'}, # Inky Rocks
    {channel_id: 'UCNCL45NnxiFKOoXB8sy6OYA'}, # The Inked Well
    {channel_id: 'UClEwjXhW8IekvkQlg2KZzAw'}, # Mike Matteson
  ]
end

def submit_video(video)
  return unless video[:macro_cluster]
  sub = CreateInkReviewSubmission.new(
    url: video[:url],
    user: user,
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

def user
  @user ||= User.first
end
