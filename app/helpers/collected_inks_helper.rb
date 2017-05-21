module CollectedInksHelper

  def privacy_link(collected_ink)
    if collected_ink.private?
      link_to(fa_icon("lock"), collected_ink_privacy_path(collected_ink), method: :delete)
    else
      link_to(fa_icon("unlock"), collected_ink_privacy_path(collected_ink), method: :post)
    end
  end
end
