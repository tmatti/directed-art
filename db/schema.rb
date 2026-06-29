# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_29_012227) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "directed_drawings", force: :cascade do |t|
    t.integer "age_band", null: false
    t.integer "canvas_height", default: 600, null: false
    t.integer "canvas_width", default: 600, null: false
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.integer "current_step", default: 0, null: false
    t.bigint "profile_id", null: false
    t.string "subject", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_directed_drawings_on_profile_id"
  end

  create_table "drawing_plans", force: :cascade do |t|
    t.string "action"
    t.integer "age_band", null: false
    t.string "background"
    t.datetime "created_at", null: false
    t.bigint "directed_drawing_id"
    t.string "mood"
    t.bigint "profile_id", null: false
    t.integer "status", default: 0, null: false
    t.string "subject"
    t.datetime "updated_at", null: false
    t.index ["directed_drawing_id"], name: "index_drawing_plans_on_directed_drawing_id"
    t.index ["profile_id"], name: "index_drawing_plans_on_profile_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.integer "age_band", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_profiles_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "active_profile_id"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["active_profile_id"], name: "index_sessions_on_active_profile_id"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "steps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "directed_drawing_id", null: false
    t.text "instruction", null: false
    t.text "narration"
    t.integer "position", null: false
    t.jsonb "primitives", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["directed_drawing_id", "position"], name: "index_steps_on_directed_drawing_id_and_position", unique: true
  end

  create_table "subject_rejections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "drawing_plan_id", null: false
    t.bigint "profile_id", null: false
    t.text "subject", null: false
    t.datetime "updated_at", null: false
    t.index ["drawing_plan_id"], name: "index_subject_rejections_on_drawing_plan_id"
    t.index ["profile_id"], name: "index_subject_rejections_on_profile_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "directed_drawings", "profiles"
  add_foreign_key "drawing_plans", "directed_drawings", on_delete: :nullify
  add_foreign_key "drawing_plans", "profiles"
  add_foreign_key "profiles", "users"
  add_foreign_key "sessions", "profiles", column: "active_profile_id", on_delete: :nullify
  add_foreign_key "sessions", "users"
  add_foreign_key "steps", "directed_drawings"
  add_foreign_key "subject_rejections", "drawing_plans"
  add_foreign_key "subject_rejections", "profiles"
end
