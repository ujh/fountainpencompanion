class CreateAuthenticationTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :authentication_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :name, null: false
      t.datetime :last_used_at

      t.timestamps
    end
  end
end
