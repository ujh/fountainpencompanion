Rails.application.config.after_initialize do
  sample = <<~MARKDOWN
    # Heading

    *em* **strong** "quotes" -- ... `code` <span>html</span> &amp; \\* https://example.com
    [link](https://example.com "title") ![image](https://example.com/i.png) [ref][r] foo[^1]
    *[HTML]: Hypertext

    > quote

    - item
    1. item

    | a | b |
    |---|---|
    | 1 | 2 |

    ~~~ ruby
    code
    ~~~

    $$x^2$$

    term
    : definition

    ***

    <div markdown="1">*x*</div>
    {: .c}

    [r]: https://example.com
    [^1]: note
  MARKDOWN

  [FpcFormatter, BlogPostFormatter].each { |formatter| formatter.new(sample).complete }
end
