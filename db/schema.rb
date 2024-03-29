# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150408210038) do

  create_table "bookmarks", force: :cascade do |t|
    t.integer  "user_id",                 null: false
    t.string   "document_id", limit: 255
    t.string   "title",       limit: 255
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.string   "user_type",   limit: 255
  end

  create_table "pronom_format_types", force: :cascade do |t|
    t.string "pronom_format_type"
    t.string "pronom_format_id"
  end

  add_index "pronom_format_types", ["pronom_format_id"], name: "index_pronom_format_types_on_pronom_format_id"
  add_index "pronom_format_types", ["pronom_format_type"], name: "index_pronom_format_types_on_pronom_format_type"

  create_table "pronom_formats", id: false, force: :cascade do |t|
    t.string "id"
    t.string "uri"
    t.string "pcdm_type"
  end

  add_index "pronom_formats", ["pcdm_type"], name: "index_pronom_formats_on_pcdm_type"
  add_index "pronom_formats", ["uri"], name: "index_pronom_formats_on_uri"

  create_table "searches", force: :cascade do |t|
    t.text     "query_params"
    t.integer  "user_id"
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.string   "user_type",    limit: 255
  end

  add_index "searches", ["user_id"], name: "index_searches_on_user_id"

end
