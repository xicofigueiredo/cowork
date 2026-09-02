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

ActiveRecord::Schema[8.1].define(version: 2026_09_03_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bookings", force: :cascade do |t|
    t.string "booking_type", null: false
    t.datetime "created_at", null: false
    t.bigint "credit_pack_id"
    t.date "date"
    t.datetime "ends_at"
    t.date "ends_on"
    t.bigint "order_id"
    t.bigint "seat_id", null: false
    t.datetime "starts_at"
    t.date "starts_on"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["credit_pack_id"], name: "index_bookings_on_credit_pack_id"
    t.index ["order_id"], name: "index_bookings_on_order_id"
    t.index ["seat_id", "date"], name: "index_bookings_on_seat_and_meeting_daily_date", unique: true, where: "((booking_type)::text = 'meeting_daily'::text)"
    t.index ["seat_id", "date"], name: "index_bookings_on_seat_id_and_date", unique: true, where: "((booking_type)::text = 'daily'::text)"
    t.index ["seat_id", "starts_at"], name: "index_bookings_on_seat_and_meeting_hourly_starts_at", unique: true, where: "((booking_type)::text = 'meeting_hourly'::text)"
    t.index ["seat_id"], name: "index_bookings_on_seat_id"
    t.index ["user_id"], name: "index_bookings_on_user_id"
  end

  create_table "credit_packs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "credit_type", default: "day", null: false
    t.datetime "expires_at", null: false
    t.bigint "order_id", null: false
    t.integer "remaining_credits", null: false
    t.integer "total_credits", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["order_id"], name: "index_credit_packs_on_order_id"
    t.index ["user_id"], name: "index_credit_packs_on_user_id"
  end

  create_table "leads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.text "message"
    t.boolean "privacy_accepted", default: false, null: false
    t.datetime "updated_at", null: false
  end

  create_table "orders", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.date "booking_date"
    t.datetime "created_at", null: false
    t.datetime "paid_at"
    t.string "plan_type", null: false
    t.bigint "seat_id"
    t.datetime "starts_at"
    t.string "status", default: "pending", null: false
    t.string "stripe_session_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["seat_id"], name: "index_orders_on_seat_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "seats", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "floor", null: false
    t.string "kind", default: "desk", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_seats_on_code", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "bookings", "credit_packs"
  add_foreign_key "bookings", "orders"
  add_foreign_key "bookings", "seats"
  add_foreign_key "bookings", "users"
  add_foreign_key "credit_packs", "orders"
  add_foreign_key "credit_packs", "users"
  add_foreign_key "orders", "seats"
  add_foreign_key "orders", "users"
end
