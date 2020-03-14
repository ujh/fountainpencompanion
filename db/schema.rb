# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_03_14_133313) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "fuzzystrmatch"
  enable_extension "plpgsql"

  create_table "admins", force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.inet "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_sign_in_at"
    t.inet "last_sign_in_ip"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "collected_inks", id: :serial, force: :cascade do |t|
    t.date "archived_on"
    t.string "brand_name", limit: 100, null: false
    t.string "color", limit: 7, default: "", null: false
    t.text "comment", default: ""
    t.datetime "created_at", null: false
    t.integer "currently_inked_count", default: 0
    t.string "ink_name", limit: 100, null: false
    t.string "kind"
    t.string "line_name", limit: 100, default: "", null: false
    t.text "maker", default: ""
    t.bigint "micro_cluster_id"
    t.integer "new_ink_name_id"
    t.boolean "private", default: false
    t.text "private_comment"
    t.string "simplified_brand_name", limit: 100
    t.string "simplified_ink_name", limit: 100
    t.string "simplified_line_name", limit: 100
    t.boolean "swabbed", default: false, null: false
    t.datetime "updated_at", null: false
    t.boolean "used", default: false, null: false
    t.integer "user_id", null: false
    t.index ["brand_name"], name: "index_collected_inks_on_brand_name"
    t.index ["ink_name"], name: "index_collected_inks_on_ink_name"
    t.index ["line_name"], name: "index_collected_inks_on_line_name"
    t.index ["micro_cluster_id"], name: "index_collected_inks_on_micro_cluster_id"
    t.index ["simplified_ink_name"], name: "index_collected_inks_on_simplified_ink_name"
  end

  create_table "collected_pens", force: :cascade do |t|
    t.date "archived_on"
    t.string "brand", limit: 100, null: false
    t.string "color", limit: 100
    t.text "comment"
    t.datetime "created_at", null: false
    t.string "model", limit: 100, null: false
    t.string "nib", limit: 100
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
  end

  create_table "currently_inked", force: :cascade do |t|
    t.date "archived_on"
    t.bigint "collected_ink_id", null: false
    t.bigint "collected_pen_id", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.date "inked_on", null: false
    t.string "nib", limit: 100, default: ""
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["collected_ink_id"], name: "index_currently_inked_on_collected_ink_id"
    t.index ["collected_pen_id"], name: "index_currently_inked_on_collected_pen_id"
    t.index ["user_id"], name: "index_currently_inked_on_user_id"
  end

  create_table "ink_brands", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "popular_name"
    t.text "simplified_name"
    t.datetime "updated_at", null: false
    t.index ["simplified_name"], name: "index_ink_brands_on_simplified_name", unique: true
  end

  create_table "macro_clusters", force: :cascade do |t|
    t.string "brand_name", default: ""
    t.string "color", limit: 7, default: "", null: false
    t.datetime "created_at", precision: 6, null: false
    t.string "ink_name", default: ""
    t.string "line_name", default: ""
    t.datetime "updated_at", precision: 6, null: false
    t.index ["brand_name", "line_name", "ink_name"], name: "index_macro_clusters_on_brand_name_and_line_name_and_ink_name", unique: true
  end

  create_table "micro_clusters", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.bigint "macro_cluster_id"
    t.text "simplified_brand_name", null: false
    t.text "simplified_ink_name", null: false
    t.text "simplified_line_name", default: ""
    t.datetime "updated_at", precision: 6, null: false
    t.index ["macro_cluster_id"], name: "index_micro_clusters_on_macro_cluster_id"
    t.index ["simplified_brand_name", "simplified_line_name", "simplified_ink_name"], name: "unique_micro_clusters", unique: true
  end

  create_table "new_ink_names", force: :cascade do |t|
    t.string "color", limit: 7, default: "", null: false
    t.datetime "created_at", null: false
    t.integer "ink_brand_id", null: false
    t.text "popular_line_name", default: ""
    t.text "popular_name"
    t.text "simplified_name", null: false
    t.datetime "updated_at", null: false
    t.index ["popular_line_name"], name: "index_new_ink_names_on_popular_line_name"
    t.index ["popular_name"], name: "index_new_ink_names_on_popular_name"
    t.index ["simplified_name", "ink_brand_id"], name: "index_new_ink_names_on_simplified_name_and_ink_brand_id", unique: true
  end

  create_table "usage_records", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "currently_inked_id", null: false
    t.datetime "updated_at", null: false
    t.date "used_on", null: false
    t.index ["currently_inked_id", "used_on"], name: "index_usage_records_on_currently_inked_id_and_used_on", unique: true
    t.index ["currently_inked_id"], name: "index_usage_records_on_currently_inked_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.text "blurb", default: ""
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.inet "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_sign_in_at"
    t.inet "last_sign_in_ip"
    t.string "name", limit: 100
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "collected_inks", "micro_clusters"
  add_foreign_key "collected_inks", "new_ink_names"
  add_foreign_key "collected_inks", "users"
  add_foreign_key "collected_pens", "users"
  add_foreign_key "currently_inked", "collected_inks"
  add_foreign_key "currently_inked", "collected_pens"
  add_foreign_key "currently_inked", "users"
  add_foreign_key "micro_clusters", "macro_clusters"
  add_foreign_key "new_ink_names", "ink_brands"
  add_foreign_key "usage_records", "currently_inked"
end
