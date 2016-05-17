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

ActiveRecord::Schema.define(version: 20160517015940) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "playlists", force: :cascade do |t|
    t.string   "playlist_id",   null: false
    t.string   "name"
    t.string   "owner"
    t.string   "url"
    t.boolean  "public"
    t.boolean  "collaborative"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  create_table "tracks", force: :cascade do |t|
    t.string   "track_id",     null: false
    t.string   "name"
    t.string   "artist_id"
    t.string   "album_id"
    t.integer  "disc_number"
    t.integer  "track_number"
    t.boolean  "explicit"
    t.integer  "duration_ms"
    t.string   "url"
    t.string   "preview_url"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "user_id",              null: false
    t.string   "access_token"
    t.datetime "expiry_date"
    t.string   "refresh_token"
    t.string   "selected_playlist_id"
    t.string   "url"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

end
