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

ActiveRecord::Schema[7.1].define(version: 2026_07_15_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "attendances", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "event_id", null: false
    t.bigint "team_id"
    t.bigint "checked_in_by_id"
    t.datetime "checked_in_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "checked_in_date", null: false
    t.datetime "checked_out_at"
    t.bigint "checked_out_by_id"
    t.string "source", default: "qr_code", null: false
    t.index ["checked_in_by_id"], name: "index_attendances_on_checked_in_by_id"
    t.index ["event_id"], name: "index_attendances_on_event_id"
    t.index ["source"], name: "index_attendances_on_source"
    t.index ["team_id"], name: "index_attendances_on_team_id"
    t.index ["user_id", "event_id", "checked_in_date"], name: "index_attendances_unique_per_day", unique: true
    t.index ["user_id"], name: "index_attendances_on_user_id"
  end

  create_table "badge_configs", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.integer "photo_size", default: 115
    t.integer "name_font_size", default: 20
    t.integer "role_chip_font_size", default: 13
    t.integer "team_info_font_size", default: 12
    t.integer "event_name_font_size", default: 14
    t.integer "event_date_font_size", default: 6
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "event_name_color", default: "#4ade80"
    t.string "header_footer_color", default: "#0d0d0d"
    t.string "body_color", default: "#f5f5f4"
    t.string "name_color", default: "#18181b"
    t.string "team_info_color", default: "#52525b"
    t.integer "credential_code_font_size", default: 8
    t.string "credential_code_color", default: "#a1a1aa"
    t.string "layout", default: "classic", null: false
    t.index ["event_id"], name: "index_badge_configs_on_event_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.string "cnpj"
    t.string "phone"
    t.string "email"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "primary_color", default: "#18181b"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "plan_id"
    t.index ["plan_id"], name: "index_companies_on_plan_id"
  end

  create_table "company_users", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "operator", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "user_id"], name: "index_company_users_on_company_id_and_user_id", unique: true
    t.index ["company_id"], name: "index_company_users_on_company_id"
    t.index ["user_id"], name: "index_company_users_on_user_id"
  end

  create_table "event_days", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.date "date", null: false
    t.decimal "hours", precision: 4, scale: 1, default: "8.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "date"], name: "index_event_days_on_event_id_and_date", unique: true
    t.index ["event_id"], name: "index_event_days_on_event_id"
  end

  create_table "event_functions", force: :cascade do |t|
    t.bigint "event_id"
    t.string "name", null: false
    t.decimal "hourly_rate", precision: 8, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "name"], name: "index_event_functions_on_event_id_and_name", unique: true, where: "(event_id IS NOT NULL)"
    t.index ["event_id"], name: "index_event_functions_on_event_id"
    t.index ["name"], name: "index_event_functions_catalog_name", unique: true, where: "(event_id IS NULL)"
  end

  create_table "events", force: :cascade do |t|
    t.string "name", null: false
    t.string "location"
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.string "status", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code"
    t.bigint "company_id"
    t.datetime "closing_finalized_at"
    t.integer "closing_finalized_by_id"
    t.string "event_type"
    t.index ["closing_finalized_by_id"], name: "index_events_on_closing_finalized_by_id"
    t.index ["company_id"], name: "index_events_on_company_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "user_id", null: false
    t.bigint "paid_by_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.decimal "hours", precision: 8, scale: 2
    t.decimal "hourly_rate", precision: 10, scale: 2
    t.string "function_name"
    t.string "payment_method", default: "pix"
    t.string "basis", default: "shifts", null: false
    t.text "notes"
    t.datetime "paid_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "waived", default: false, null: false
    t.string "waived_reason"
    t.date "date"
    t.index ["event_id"], name: "index_payments_on_event_id"
    t.index ["paid_by_id"], name: "index_payments_on_paid_by_id"
    t.index ["user_id", "event_id", "date"], name: "index_payments_on_user_id_and_event_id_and_date", unique: true
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.bigint "role_id", null: false
    t.string "resource", null: false
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id", "resource", "action"], name: "index_permissions_on_role_id_and_resource_and_action", unique: true
    t.index ["role_id"], name: "index_permissions_on_role_id"
  end

  create_table "plans", force: :cascade do |t|
    t.string "name", null: false
    t.integer "events_limit"
    t.integer "members_limit"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_plans_on_name", unique: true
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "collaborator", default: false, null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "sector_functions", force: :cascade do |t|
    t.bigint "sector_id", null: false
    t.bigint "event_function_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_function_id"], name: "index_sector_functions_on_event_function_id"
    t.index ["sector_id", "event_function_id"], name: "index_sector_functions_on_sector_id_and_event_function_id", unique: true
    t.index ["sector_id"], name: "index_sector_functions_on_sector_id"
  end

  create_table "sectors", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "event_id", null: false
    t.string "sector_type"
    t.index ["event_id"], name: "index_sectors_on_event_id"
    t.index ["sector_type"], name: "index_sectors_on_sector_type"
  end

  create_table "shifts", force: :cascade do |t|
    t.date "date", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.bigint "user_id", null: false
    t.bigint "sector_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "team_id"
    t.date "end_date"
    t.index ["sector_id"], name: "index_shifts_on_sector_id"
    t.index ["team_id"], name: "index_shifts_on_team_id"
    t.index ["user_id", "date"], name: "index_shifts_on_user_id_and_date"
    t.index ["user_id"], name: "index_shifts_on_user_id"
  end

  create_table "team_memberships", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "credential_code"
    t.bigint "event_function_id"
    t.integer "role", default: 0, null: false
    t.boolean "substitute", default: false, null: false
    t.index ["credential_code"], name: "index_team_memberships_on_credential_code", unique: true
    t.index ["event_function_id"], name: "index_team_memberships_on_event_function_id"
    t.index ["team_id", "user_id"], name: "index_team_memberships_on_team_id_and_user_id", unique: true
    t.index ["team_id"], name: "index_team_memberships_on_team_id"
    t.index ["user_id"], name: "index_team_memberships_on_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "sector_id", null: false
    t.bigint "coordinator_id"
    t.string "coordinator_credential_code"
    t.string "radio_channel"
    t.index ["coordinator_credential_code"], name: "index_teams_on_coordinator_credential_code", unique: true
    t.index ["coordinator_id"], name: "index_teams_on_coordinator_id"
    t.index ["sector_id"], name: "index_teams_on_sector_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "cpf"
    t.string "phone"
    t.bigint "role_id"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "invitation_token"
    t.datetime "invitation_accepted_at"
    t.datetime "onboarding_completed_at"
    t.bigint "invited_by_id"
    t.index ["cpf"], name: "index_users_on_cpf", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
  end

  create_table "vehicles", force: :cascade do |t|
    t.string "model", null: false
    t.string "color"
    t.string "license_plate", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["license_plate"], name: "index_vehicles_on_license_plate", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attendances", "events"
  add_foreign_key "attendances", "teams"
  add_foreign_key "attendances", "users"
  add_foreign_key "attendances", "users", column: "checked_in_by_id"
  add_foreign_key "attendances", "users", column: "checked_out_by_id"
  add_foreign_key "badge_configs", "events"
  add_foreign_key "companies", "plans"
  add_foreign_key "company_users", "companies"
  add_foreign_key "company_users", "users"
  add_foreign_key "event_days", "events"
  add_foreign_key "event_functions", "events"
  add_foreign_key "events", "companies"
  add_foreign_key "payments", "events"
  add_foreign_key "payments", "users"
  add_foreign_key "payments", "users", column: "paid_by_id"
  add_foreign_key "permissions", "roles"
  add_foreign_key "sector_functions", "event_functions"
  add_foreign_key "sector_functions", "sectors"
  add_foreign_key "sectors", "events"
  add_foreign_key "shifts", "sectors"
  add_foreign_key "shifts", "teams"
  add_foreign_key "shifts", "users"
  add_foreign_key "team_memberships", "event_functions"
  add_foreign_key "team_memberships", "teams"
  add_foreign_key "team_memberships", "users"
  add_foreign_key "teams", "sectors"
  add_foreign_key "teams", "users", column: "coordinator_id"
  add_foreign_key "users", "roles"
end
