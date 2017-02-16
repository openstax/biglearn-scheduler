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

ActiveRecord::Schema.define(version: 20170216003441) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "assignment_pes", force: :cascade do |t|
    t.uuid     "uuid",            null: false
    t.uuid     "assignment_uuid", null: false
    t.uuid     "exercise_uuid",   null: false
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "assignment_pes", ["assignment_uuid"], name: "index_assignment_pes_on_assignment_uuid", using: :btree
  add_index "assignment_pes", ["exercise_uuid", "assignment_uuid"], name: "index_assignment_pes_on_exercise_uuid_and_assignment_uuid", unique: true, using: :btree
  add_index "assignment_pes", ["uuid"], name: "index_assignment_pes_on_uuid", unique: true, using: :btree

  create_table "assignment_spes", force: :cascade do |t|
    t.uuid     "uuid",            null: false
    t.uuid     "assignment_uuid", null: false
    t.uuid     "exercise_uuid",   null: false
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "assignment_spes", ["assignment_uuid"], name: "index_assignment_spes_on_assignment_uuid", using: :btree
  add_index "assignment_spes", ["exercise_uuid", "assignment_uuid"], name: "index_assignment_spes_on_exercise_uuid_and_assignment_uuid", unique: true, using: :btree
  add_index "assignment_spes", ["uuid"], name: "index_assignment_spes_on_uuid", unique: true, using: :btree

  create_table "assignments", force: :cascade do |t|
    t.uuid     "uuid",                          null: false
    t.uuid     "course_uuid",                   null: false
    t.uuid     "student_uuid",                  null: false
    t.string   "assignment_type",               null: false
    t.uuid     "assigned_book_container_uuids", null: false, array: true
    t.uuid     "assigned_exercise_uuids",       null: false, array: true
    t.integer  "goal_num_spes",                 null: false
    t.integer  "goal_num_pes",                  null: false
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  add_index "assignments", ["course_uuid"], name: "index_assignments_on_course_uuid", using: :btree
  add_index "assignments", ["goal_num_pes"], name: "index_assignments_on_goal_num_pes", using: :btree
  add_index "assignments", ["goal_num_spes"], name: "index_assignments_on_goal_num_spes", using: :btree
  add_index "assignments", ["student_uuid"], name: "index_assignments_on_student_uuid", using: :btree
  add_index "assignments", ["uuid"], name: "index_assignments_on_uuid", unique: true, using: :btree

  create_table "course_containers", force: :cascade do |t|
    t.uuid     "uuid",          null: false
    t.uuid     "course_uuid",   null: false
    t.uuid     "student_uuids", null: false, array: true
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "course_containers", ["course_uuid"], name: "index_course_containers_on_course_uuid", using: :btree
  add_index "course_containers", ["uuid"], name: "index_course_containers_on_uuid", unique: true, using: :btree

  create_table "courses", force: :cascade do |t|
    t.uuid     "uuid",                                 null: false
    t.integer  "sequence_number",                      null: false
    t.uuid     "ecosystem_uuid",                       null: false
    t.uuid     "course_excluded_exercise_uuids",       null: false, array: true
    t.uuid     "course_excluded_exercise_group_uuids", null: false, array: true
    t.uuid     "global_excluded_exercise_uuids",       null: false, array: true
    t.uuid     "global_excluded_exercise_group_uuids", null: false, array: true
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
  end

  add_index "courses", ["ecosystem_uuid"], name: "index_courses_on_ecosystem_uuid", using: :btree
  add_index "courses", ["uuid"], name: "index_courses_on_uuid", unique: true, using: :btree

  create_table "ecosystems", force: :cascade do |t|
    t.uuid     "uuid",            null: false
    t.integer  "sequence_number", null: false
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "ecosystems", ["uuid"], name: "index_ecosystems_on_uuid", unique: true, using: :btree

  create_table "exercise_pools", force: :cascade do |t|
    t.uuid     "uuid",                                      null: false
    t.uuid     "ecosystem_uuid",                            null: false
    t.uuid     "book_container_uuid",                       null: false
    t.boolean  "use_for_clue",                              null: false
    t.string   "use_for_personalized_for_assignment_types", null: false, array: true
    t.uuid     "exercise_uuids",                            null: false, array: true
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
  end

  add_index "exercise_pools", ["book_container_uuid"], name: "index_exercise_pools_on_book_container_uuid", using: :btree
  add_index "exercise_pools", ["ecosystem_uuid"], name: "index_exercise_pools_on_ecosystem_uuid", using: :btree
  add_index "exercise_pools", ["use_for_clue"], name: "index_exercise_pools_on_use_for_clue", using: :btree
  add_index "exercise_pools", ["uuid"], name: "index_exercise_pools_on_uuid", unique: true, using: :btree

  create_table "exercises", force: :cascade do |t|
    t.uuid     "uuid",                null: false
    t.uuid     "group_uuid",          null: false
    t.integer  "version",             null: false
    t.uuid     "exercise_pool_uuids", null: false, array: true
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
  end

  add_index "exercises", ["group_uuid", "version"], name: "index_exercises_on_group_uuid_and_version", unique: true, using: :btree
  add_index "exercises", ["uuid"], name: "index_exercises_on_uuid", unique: true, using: :btree

  create_table "responses", force: :cascade do |t|
    t.uuid     "uuid",          null: false
    t.uuid     "student_uuid",  null: false
    t.uuid     "exercise_uuid", null: false
    t.boolean  "is_correct",    null: false
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "responses", ["exercise_uuid"], name: "index_responses_on_exercise_uuid", using: :btree
  add_index "responses", ["student_uuid"], name: "index_responses_on_student_uuid", using: :btree
  add_index "responses", ["uuid"], name: "index_responses_on_uuid", unique: true, using: :btree

  create_table "student_pes", force: :cascade do |t|
    t.uuid     "uuid",          null: false
    t.uuid     "student_uuid",  null: false
    t.uuid     "exercise_uuid", null: false
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "student_pes", ["exercise_uuid", "student_uuid"], name: "index_student_pes_on_exercise_uuid_and_student_uuid", unique: true, using: :btree
  add_index "student_pes", ["student_uuid"], name: "index_student_pes_on_student_uuid", using: :btree
  add_index "student_pes", ["uuid"], name: "index_student_pes_on_uuid", unique: true, using: :btree

  create_table "students", force: :cascade do |t|
    t.uuid     "uuid",                   null: false
    t.uuid     "course_uuid",            null: false
    t.uuid     "course_container_uuids", null: false, array: true
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "students", ["course_uuid"], name: "index_students_on_course_uuid", using: :btree
  add_index "students", ["uuid"], name: "index_students_on_uuid", unique: true, using: :btree

end
