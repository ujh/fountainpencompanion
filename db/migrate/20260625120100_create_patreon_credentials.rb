class CreatePatreonCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :patreon_credentials do |t|
      t.string :access_token, null: false
      t.string :refresh_token, null: false
      t.datetime :expires_at

      t.timestamps
    end
  end
end
