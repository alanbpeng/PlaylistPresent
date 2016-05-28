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

ActiveRecord::Schema.define(version: 20160517054013) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "album_artists", force: :cascade do |t|
    t.integer  "album_id",   null: false
    t.integer  "artist_id",  null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "album_artists", ["album_id"], name: "index_album_artists_on_album_id", using: :btree

  create_table "albums", force: :cascade do |t|
    t.string   "album_id",          null: false
    t.string   "name"
    t.string   "image_url"
    t.string   "year"
    t.string   "available_markets"
    t.string   "url"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  add_index "albums", ["album_id"], name: "index_albums_on_album_id", unique: true, using: :btree

  create_table "artists", force: :cascade do |t|
    t.string   "artist_id",  null: false
    t.string   "name"
    t.string   "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "artists", ["artist_id"], name: "index_artists_on_artist_id", unique: true, using: :btree

  create_table "playlists", force: :cascade do |t|
    t.string   "playlist_id",   null: false
    t.string   "name"
    t.string   "owner"
    t.string   "owner_url"
    t.string   "url"
    t.boolean  "public"
    t.boolean  "collaborative"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "playlists", ["playlist_id"], name: "index_playlists_on_playlist_id", unique: true, using: :btree

  create_table "track_artists", force: :cascade do |t|
    t.integer  "track_id",   null: false
    t.integer  "artist_id",  null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "track_artists", ["track_id"], name: "index_track_artists_on_track_id", using: :btree

  create_table "tracks", force: :cascade do |t|
    t.string   "track_id",          null: false
    t.string   "name"
    t.string   "album_id"
    t.integer  "disc_number"
    t.integer  "track_number"
    t.boolean  "explicit"
    t.integer  "duration_ms"
    t.string   "available_markets"
    t.string   "url"
    t.string   "preview_url"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  add_index "tracks", ["album_id"], name: "index_tracks_on_album_id", using: :btree
  add_index "tracks", ["track_id"], name: "index_tracks_on_track_id", unique: true, using: :btree

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

  add_index "users", ["user_id"], name: "index_users_on_user_id", unique: true, using: :btree

end
