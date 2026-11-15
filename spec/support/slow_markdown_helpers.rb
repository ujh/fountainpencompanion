module SlowMarkdownHelpers
  SLOW_MARKDOWN = "A text that takes too long to render"

  def make_markdown_slow
    stub_const("FpcFormatter::RENDER_TIMEOUT", 0.05)
    allow(Kramdown::Document).to receive(:new).and_wrap_original do |original, source, *args|
      sleep 5 if source == SLOW_MARKDOWN
      original.call(source, *args)
    end
  end
end
