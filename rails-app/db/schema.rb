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

ActiveRecord::Schema[8.1].define(version: 2026_10_16_000100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "approvals", force: :cascade do |t|
    t.string "approvable_type", null: false
    t.bigint "approvable_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "person_id"
    t.index ["approvable_type", "approvable_id"], name: "index_approvals_on_approvable"
    t.index ["approvable_type", "approvable_id"], name: "index_approvals_on_approvable_type_and_approvable_id", unique: true
    t.index ["person_id"], name: "index_approvals_on_person_id"
  end

  create_table "articles", force: :cascade do |t|
    t.string "title", null: false
    t.text "body"
  end

  create_table "buckets", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_buckets_on_name", unique: true
  end

  create_table "catalogue_allergens", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
  end

  create_table "catalogue_categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
  end

  create_table "comments", force: :cascade do |t|
    t.text "body", null: false
  end

  create_table "counter_caches", force: :cascade do |t|
    t.string "counterable_type", null: false
    t.bigint "counterable_id", null: false
    t.string "name", null: false
    t.integer "count", default: 0, null: false
    t.index ["counterable_type", "counterable_id", "name"], name: "index_counter_caches_uniqueness", unique: true
    t.index ["counterable_type", "counterable_id"], name: "index_counter_caches_on_counterable"
  end

  create_table "csv_import_rows", force: :cascade do |t|
    t.bigint "csv_import_id", null: false
    t.integer "row_number", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.string "row_hash", null: false
    t.boolean "duplicate", default: false, null: false
    t.jsonb "validation_errors"
    t.bigint "imported_recording_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["csv_import_id", "duplicate"], name: "index_csv_import_rows_on_csv_import_id_and_duplicate"
    t.index ["csv_import_id", "row_hash"], name: "index_csv_import_rows_on_csv_import_id_and_row_hash"
    t.index ["csv_import_id", "row_number"], name: "index_csv_import_rows_on_csv_import_id_and_row_number", unique: true
    t.index ["csv_import_id"], name: "index_csv_import_rows_on_csv_import_id"
    t.index ["imported_recording_id"], name: "index_csv_import_rows_on_imported_recording_id"
    t.index ["row_hash"], name: "index_csv_import_rows_on_row_hash"
  end

  create_table "csv_imports", force: :cascade do |t|
    t.bigint "bucket_id", null: false
    t.bigint "created_by_id", null: false
    t.string "import_type", limit: 50, null: false
    t.string "status", limit: 11, default: "pending", null: false
    t.string "failure_class"
    t.text "failure_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bucket_id"], name: "index_csv_imports_on_bucket_id"
    t.index ["created_by_id"], name: "index_csv_imports_on_created_by_id"
  end

  create_table "event_details", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "key", null: false
    t.text "value"
    t.index ["event_id", "key"], name: "index_event_details_on_event_id_and_key", unique: true
    t.index ["event_id"], name: "index_event_details_on_event_id"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "bucket_id", null: false
    t.string "eventable_type", null: false
    t.bigint "eventable_id", null: false
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.string "subject_previous_type"
    t.bigint "subject_previous_id"
    t.string "action", null: false
    t.bigint "person_id"
    t.datetime "created_at", null: false
    t.index ["bucket_id"], name: "index_events_on_bucket_id"
    t.index ["eventable_type", "eventable_id"], name: "index_events_on_eventable_type_and_eventable_id"
    t.index ["person_id"], name: "index_events_on_person_id"
    t.index ["subject_previous_type", "subject_previous_id"], name: "index_events_on_subject_previous"
    t.index ["subject_type", "subject_id"], name: "index_events_on_subject_type_and_subject_id"
  end

  create_table "membership_invites", force: :cascade do |t|
    t.bigint "bucket_id", null: false
    t.bigint "invited_by_id", null: false
    t.bigint "accepted_by_id"
    t.string "email_address", null: false
    t.integer "role", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.index ["accepted_by_id"], name: "index_membership_invites_on_accepted_by_id"
    t.index ["bucket_id", "email_address"], name: "index_membership_invites_on_bucket_id_and_email_address", unique: true, where: "((accepted_at IS NULL) AND (revoked_at IS NULL))"
    t.index ["bucket_id"], name: "index_membership_invites_on_bucket_id"
    t.index ["invited_by_id"], name: "index_membership_invites_on_invited_by_id"
    t.index ["token_digest"], name: "index_membership_invites_on_token_digest", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "bucket_id", null: false
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bucket_id"], name: "index_memberships_on_bucket_id"
    t.index ["person_id", "bucket_id"], name: "index_memberships_on_person_id_and_bucket_id", unique: true
    t.index ["person_id"], name: "index_memberships_on_person_id"
  end

  create_table "people", force: :cascade do |t|
    t.bigint "recording_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recording_id"], name: "index_people_on_recording_id"
  end

  create_table "person_cards", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
  end

  create_table "publications", force: :cascade do |t|
    t.string "publishable_type", null: false
    t.bigint "publishable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["publishable_type", "publishable_id"], name: "index_publications_on_publishable", unique: true
  end

  create_table "recordings", force: :cascade do |t|
    t.bigint "bucket_id", null: false
    t.bigint "parent_id"
    t.string "recordable_type", null: false
    t.bigint "recordable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["bucket_id"], name: "index_recordings_on_bucket_id"
    t.index ["discarded_at"], name: "index_recordings_on_discarded_at"
    t.index ["parent_id"], name: "index_recordings_on_parent_id"
    t.index ["recordable_type", "recordable_id"], name: "index_recordings_on_recordable_type_and_recordable_id"
  end

  create_table "search_indices", force: :cascade do |t|
    t.bigint "recording_id", null: false
    t.string "recordable_type", null: false
    t.text "content", null: false
    t.virtual "searchable", type: :tsvector, as: "to_tsvector('english'::regconfig, content)", stored: true
    t.index ["recordable_type"], name: "index_search_indices_on_recordable_type"
    t.index ["recording_id"], name: "index_search_indices_on_recording_id", unique: true
    t.index ["searchable"], name: "index_search_indices_on_searchable", using: :gin
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "person_id", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["person_id"], name: "index_users_on_person_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "approvals", "people"
  add_foreign_key "csv_import_rows", "csv_imports"
  add_foreign_key "csv_import_rows", "recordings", column: "imported_recording_id"
  add_foreign_key "csv_imports", "buckets"
  add_foreign_key "csv_imports", "people", column: "created_by_id"
  add_foreign_key "event_details", "events"
  add_foreign_key "events", "buckets"
  add_foreign_key "events", "people"
  add_foreign_key "membership_invites", "buckets"
  add_foreign_key "membership_invites", "people", column: "accepted_by_id"
  add_foreign_key "membership_invites", "people", column: "invited_by_id"
  add_foreign_key "memberships", "buckets"
  add_foreign_key "memberships", "people"
  add_foreign_key "people", "recordings"
  add_foreign_key "recordings", "buckets"
  add_foreign_key "recordings", "recordings", column: "parent_id"
  add_foreign_key "search_indices", "recordings"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "people"
end
