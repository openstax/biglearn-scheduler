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

ActiveRecord::Schema.define(version: 20170307172053) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "assigned_exercises", force: :cascade do |t|
    t.uuid     "uuid",            null: false
    t.uuid     "assignment_uuid", null: false
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.index ["assignment_uuid"], name: "index_assigned_exercises_on_assignment_uuid", using: :btree
    t.index ["uuid"], name: "index_assigned_exercises_on_uuid", unique: true, using: :btree
  end

  create_table "assignment_pes", force: :cascade do |t|
    t.uuid     "uuid",            null: false
    t.uuid     "student_uuid",    null: false
    t.uuid     "assignment_uuid", null: false
    t.uuid     "exercise_uuid",   null: false
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.index ["assignment_uuid"], name: "index_assignment_pes_on_assignment_uuid", using: :btree
    t.index ["exercise_uuid", "assignment_uuid"], name: "index_assignment_pes_on_exercise_uuid_and_assignment_uuid", unique: true, using: :btree
    t.index ["student_uuid"], name: "index_assignment_pes_on_student_uuid", using: :btree
    t.index ["uuid"], name: "index_assignment_pes_on_uuid", unique: true, using: :btree
  end

  create_table "assignment_spes", force: :cascade do |t|
    t.uuid     "uuid",            null: false
    t.uuid     "student_uuid",    null: false
    t.uuid     "assignment_uuid", null: false
    t.uuid     "exercise_uuid",   null: false
    t.integer  "k_ago",           null: false
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.index ["assignment_uuid"], name: "index_assignment_spes_on_assignment_uuid", using: :btree
    t.index ["exercise_uuid", "assignment_uuid"], name: "index_assignment_spes_on_exercise_uuid_and_assignment_uuid", unique: true, using: :btree
    t.index ["student_uuid"], name: "index_assignment_spes_on_student_uuid", using: :btree
    t.index ["uuid"], name: "index_assignment_spes_on_uuid", unique: true, using: :btree
  end

  create_table "assignments", force: :cascade do |t|
    t.uuid     "uuid",                          null: false
    t.uuid     "course_uuid",                   null: false
    t.uuid     "ecosystem_uuid",                null: false
    t.uuid     "student_uuid",                  null: false
    t.string   "assignment_type",               null: false
    t.datetime "opens_at"
    t.datetime "due_at"
    t.uuid     "assigned_book_container_uuids", null: false, array: true
    t.uuid     "assigned_exercise_uuids",       null: false, array: true
    t.integer  "goal_num_tutor_assigned_spes",  null: false
    t.boolean  "spes_are_assigned",             null: false
    t.integer  "goal_num_tutor_assigned_pes",   null: false
    t.boolean  "pes_are_assigned",              null: false
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.index ["course_uuid"], name: "index_assignments_on_course_uuid", using: :btree
    t.index ["due_at", "opens_at", "created_at"], name: "index_assignments_on_due_at_and_opens_at_and_created_at", using: :btree
    t.index ["ecosystem_uuid"], name: "index_assignments_on_ecosystem_uuid", using: :btree
    t.index ["goal_num_tutor_assigned_pes", "pes_are_assigned"], name: "index_assignments_on_goal_num_pes_and_pes_are_assigned", using: :btree
    t.index ["goal_num_tutor_assigned_spes", "spes_are_assigned"], name: "index_assignments_on_goal_num_spes_and_spes_are_assigned", using: :btree
    t.index ["student_uuid"], name: "index_assignments_on_student_uuid", using: :btree
    t.index ["uuid"], name: "index_assignments_on_uuid", unique: true, using: :btree
  end

  create_table "book_container_mappings", force: :cascade do |t|
    t.uuid     "uuid",                     null: false
    t.uuid     "from_ecosystem_uuid",      null: false
    t.uuid     "to_ecosystem_uuid",        null: false
    t.uuid     "from_book_container_uuid", null: false
    t.uuid     "to_book_container_uuid",   null: false
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.index ["from_book_container_uuid", "from_ecosystem_uuid", "to_ecosystem_uuid"], name: "index_bcms_on_from_bc_uuid_from_eco_uuid_to_eco_uuid_unique", unique: true, using: :btree
    t.index ["from_ecosystem_uuid"], name: "index_book_container_mappings_on_from_ecosystem_uuid", using: :btree
    t.index ["to_book_container_uuid"], name: "index_book_container_mappings_on_to_book_container_uuid", using: :btree
    t.index ["to_ecosystem_uuid"], name: "index_book_container_mappings_on_to_ecosystem_uuid", using: :btree
    t.index ["uuid"], name: "index_book_container_mappings_on_uuid", unique: true, using: :btree
  end

  create_table "course_containers", force: :cascade do |t|
    t.uuid     "uuid",          null: false
    t.uuid     "course_uuid",   null: false
    t.boolean  "is_archived",   null: false
    t.uuid     "student_uuids", null: false, array: true
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.index ["uuid"], name: "index_course_containers_on_uuid", unique: true, using: :btree
  end

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
    t.index ["ecosystem_uuid"], name: "index_courses_on_ecosystem_uuid", using: :btree
    t.index ["uuid"], name: "index_courses_on_uuid", unique: true, using: :btree
  end

  create_table "ecosystem_exercises", force: :cascade do |t|
    t.uuid     "uuid",                 null: false
    t.uuid     "ecosystem_uuid",       null: false
    t.uuid     "exercise_group_uuid",  null: false
    t.uuid     "book_container_uuids", null: false, array: true
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.index ["ecosystem_uuid"], name: "index_ecosystem_exercises_on_ecosystem_uuid", using: :btree
    t.index ["exercise_group_uuid", "ecosystem_uuid"], name: "index_eco_exercises_on_exercise_group_uuid_and_eco_uuid", unique: true, using: :btree
    t.index ["uuid"], name: "index_ecosystem_exercises_on_uuid", unique: true, using: :btree
  end

  create_table "ecosystem_preparations", force: :cascade do |t|
    t.uuid     "uuid",           null: false
    t.uuid     "course_uuid",    null: false
    t.uuid     "ecosystem_uuid", null: false
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.index ["course_uuid", "ecosystem_uuid"], name: "index_ecosystem_preparations_on_course_uuid_and_ecosystem_uuid", using: :btree
    t.index ["ecosystem_uuid"], name: "index_ecosystem_preparations_on_ecosystem_uuid", using: :btree
    t.index ["uuid"], name: "index_ecosystem_preparations_on_uuid", unique: true, using: :btree
  end

  create_table "ecosystems", force: :cascade do |t|
    t.uuid     "uuid",            null: false
    t.integer  "sequence_number", null: false
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.index ["uuid"], name: "index_ecosystems_on_uuid", unique: true, using: :btree
  end

  create_table "exercise_pools", force: :cascade do |t|
    t.uuid     "uuid",                                      null: false
    t.uuid     "ecosystem_uuid",                            null: false
    t.uuid     "book_container_uuid",                       null: false
    t.boolean  "use_for_clue",                              null: false
    t.string   "use_for_personalized_for_assignment_types", null: false, array: true
    t.uuid     "exercise_uuids",                            null: false, array: true
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.index ["book_container_uuid"], name: "index_exercise_pools_on_book_container_uuid", using: :btree
    t.index ["ecosystem_uuid"], name: "index_exercise_pools_on_ecosystem_uuid", using: :btree
    t.index ["use_for_clue"], name: "index_exercise_pools_on_use_for_clue", using: :btree
    t.index ["uuid"], name: "index_exercise_pools_on_uuid", unique: true, using: :btree
  end

  create_table "exercises", force: :cascade do |t|
    t.uuid     "uuid",       null: false
    t.uuid     "group_uuid", null: false
    t.integer  "version",    null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_uuid", "version"], name: "index_exercises_on_group_uuid_and_version", using: :btree
    t.index ["uuid"], name: "index_exercises_on_uuid", unique: true, using: :btree
  end

  create_table "response_clues", force: :cascade do |t|
    t.uuid     "uuid",        null: false
    t.uuid     "course_uuid", null: false
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.index ["course_uuid"], name: "index_response_clues_on_course_uuid", using: :btree
    t.index ["uuid"], name: "index_response_clues_on_uuid", unique: true, using: :btree
  end

  create_table "responses", force: :cascade do |t|
    t.uuid     "uuid",          null: false
    t.uuid     "student_uuid",  null: false
    t.uuid     "exercise_uuid", null: false
    t.datetime "responded_at",  null: false
    t.boolean  "is_correct",    null: false
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.index ["exercise_uuid"], name: "index_responses_on_exercise_uuid", using: :btree
    t.index ["responded_at"], name: "index_responses_on_responded_at", using: :btree
    t.index ["student_uuid"], name: "index_responses_on_student_uuid", using: :btree
    t.index ["uuid"], name: "index_responses_on_uuid", unique: true, using: :btree
  end

  create_table "student_clues", force: :cascade do |t|
    t.uuid     "uuid",                null: false
    t.uuid     "student_uuid",        null: false
    t.uuid     "book_container_uuid", null: false
    t.decimal  "value",               null: false
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
    t.index ["book_container_uuid", "student_uuid"], name: "index_student_clues_on_book_container_uuid_and_student_uuid", unique: true, using: :btree
    t.index ["student_uuid", "value"], name: "index_student_clues_on_student_uuid_and_value", using: :btree
    t.index ["uuid"], name: "index_student_clues_on_uuid", unique: true, using: :btree
  end

  create_table "student_pes", force: :cascade do |t|
    t.uuid     "uuid",                null: false
    t.uuid     "book_container_uuid", null: false
    t.uuid     "student_uuid",        null: false
    t.uuid     "exercise_uuid",       null: false
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
    t.index ["book_container_uuid"], name: "index_student_pes_on_book_container_uuid", using: :btree
    t.index ["exercise_uuid", "student_uuid"], name: "index_student_pes_on_exercise_uuid_and_student_uuid", unique: true, using: :btree
    t.index ["student_uuid"], name: "index_student_pes_on_student_uuid", using: :btree
    t.index ["uuid"], name: "index_student_pes_on_uuid", unique: true, using: :btree
  end

  create_table "students", force: :cascade do |t|
    t.uuid     "uuid",                   null: false
    t.uuid     "course_uuid",            null: false
    t.uuid     "course_container_uuids", null: false, array: true
    t.boolean  "pes_are_assigned",       null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.index ["course_uuid"], name: "index_students_on_course_uuid", using: :btree
    t.index ["uuid"], name: "index_students_on_uuid", unique: true, using: :btree
  end

end
