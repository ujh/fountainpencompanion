class CreateBlogPosts < ActiveRecord::Migration[6.0]
  def change
    create_table :blog_posts do |t|
      t.text :title
      t.text :body
      t.datetime :published_at

      t.timestamps
    end
  end
end
