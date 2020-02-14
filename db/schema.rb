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

ActiveRecord::Schema.define(version: 2020_02_14_174356) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

  create_table "algorithm_ecosystem_matrix_updates", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "ecosystem_matrix_update_uuid", null: false
    t.citext "algorithm_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ecosystem_matrix_update_uuid", "algorithm_name"], name: "index_alg_eco_mat_up_on_eco_mat_up_uuid_and_alg_name", unique: true
    t.index ["uuid"], name: "index_algorithm_ecosystem_matrix_updates_on_uuid", unique: true
  end

  create_table "algorithm_exercise_calculations", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "exercise_calculation_uuid", null: false
    t.citext "algorithm_name", null: false
    t.uuid "exercise_uuids", null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_pending_for_student", default: true, null: false
    t.string "pending_assignment_uuids", null: false, array: true
    t.uuid "ecosystem_matrix_uuid", null: false
    t.index "cardinality(pending_assignment_uuids)", name: "index_alg_ex_calc_on_cardinality_of_pending_assignment_uuids"
    t.index ["ecosystem_matrix_uuid"], name: "index_algorithm_exercise_calculations_on_ecosystem_matrix_uuid"
    t.index ["exercise_calculation_uuid", "algorithm_name"], name: "index_alg_ex_calc_on_ex_calc_uuid_and_alg_name", unique: true
    t.index ["is_pending_for_student"], name: "index_algorithm_exercise_calculations_on_is_pending_for_student"
    t.index ["uuid"], name: "index_algorithm_exercise_calculations_on_uuid", unique: true
  end

  create_table "algorithm_student_clue_calculations", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "student_clue_calculation_uuid", null: false
    t.citext "algorithm_name", null: false
    t.jsonb "clue_data", null: false
    t.decimal "clue_value", null: false
    t.boolean "is_uploaded", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clue_value"], name: "index_algorithm_student_clue_calculations_on_clue_value"
    t.index ["is_uploaded"], name: "index_algorithm_student_clue_calculations_on_is_uploaded"
    t.index ["student_clue_calculation_uuid", "algorithm_name"], name: "index_alg_s_clue_calc_on_s_clue_calc_uuid_and_alg_name", unique: true
    t.index ["uuid"], name: "index_algorithm_student_clue_calculations_on_uuid", unique: true
  end

  create_table "algorithm_teacher_clue_calculations", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "teacher_clue_calculation_uuid", null: false
    t.citext "algorithm_name", null: false
    t.jsonb "clue_data", null: false
    t.boolean "is_uploaded", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_uploaded"], name: "index_algorithm_teacher_clue_calculations_on_is_uploaded"
    t.index ["teacher_clue_calculation_uuid", "algorithm_name"], name: "index_alg_t_clue_calc_on_t_clue_calc_uuid_and_alg_name", unique: true
    t.index ["uuid"], name: "index_algorithm_teacher_clue_calculations_on_uuid", unique: true
  end

  create_table "assigned_exercises", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "assignment_uuid", null: false
    t.uuid "exercise_uuid", null: false
    t.boolean "is_spe", null: false
    t.boolean "is_pe", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_uuid", "is_spe", "is_pe"], name: "index_assigned_exercises_on_a_uuid_and_is_spe_and_is_pe"
    t.index ["exercise_uuid"], name: "index_assigned_exercises_on_exercise_uuid"
    t.index ["uuid"], name: "index_assigned_exercises_on_uuid", unique: true
  end

  create_table "assignment_pes", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "algorithm_exercise_calculation_uuid", null: false
    t.uuid "assignment_uuid", null: false
    t.uuid "exercise_uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["algorithm_exercise_calculation_uuid"], name: "index_assignment_pes_on_algorithm_exercise_calculation_uuid"
    t.index ["assignment_uuid", "algorithm_exercise_calculation_uuid", "exercise_uuid"], name: "index_a_pes_on_a_uuid_alg_ex_calc_uuid_and_ex_uuid", unique: true
    t.index ["exercise_uuid"], name: "index_assignment_pes_on_exercise_uuid"
    t.index ["uuid"], name: "index_assignment_pes_on_uuid", unique: true
  end

  create_table "assignment_spes", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "algorithm_exercise_calculation_uuid", null: false
    t.uuid "assignment_uuid", null: false
    t.uuid "exercise_uuid", null: false
    t.integer "history_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["algorithm_exercise_calculation_uuid"], name: "index_assignment_spes_on_algorithm_exercise_calculation_uuid"
    t.index ["assignment_uuid", "algorithm_exercise_calculation_uuid", "history_type", "exercise_uuid"], name: "index_a_spes_on_a_uuid_alg_ex_calc_uuid_h_type_and_ex_uuid", unique: true
    t.index ["exercise_uuid"], name: "index_assignment_spes_on_exercise_uuid"
    t.index ["history_type"], name: "index_assignment_spes_on_history_type"
    t.index ["uuid"], name: "index_assignment_spes_on_uuid", unique: true
  end

  create_table "assignments", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "course_uuid", null: false
    t.uuid "ecosystem_uuid", null: false
    t.uuid "student_uuid", null: false
    t.string "assignment_type", null: false
    t.datetime "opens_at"
    t.datetime "due_at"
    t.datetime "feedback_at"
    t.uuid "assigned_book_container_uuids", null: false, array: true
    t.uuid "assigned_exercise_uuids", null: false, array: true
    t.integer "goal_num_tutor_assigned_spes"
    t.boolean "spes_are_assigned", null: false
    t.integer "goal_num_tutor_assigned_pes"
    t.boolean "pes_are_assigned", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "student_history_at"
    t.boolean "has_exercise_calculation", null: false
    t.boolean "is_deleted", null: false
    t.index ["course_uuid"], name: "index_assignments_on_course_uuid"
    t.index ["due_at", "opens_at", "created_at"], name: "index_assignments_on_due_at_and_opens_at_and_created_at"
    t.index ["due_at", "student_history_at"], name: "index_assignments_on_due_at_and_student_history_at"
    t.index ["ecosystem_uuid"], name: "index_assignments_on_ecosystem_uuid"
    t.index ["feedback_at"], name: "index_assignments_on_feedback_at"
    t.index ["goal_num_tutor_assigned_pes"], name: "index_assignments_on_goal_num_tutor_assigned_pes"
    t.index ["goal_num_tutor_assigned_spes"], name: "index_assignments_on_goal_num_tutor_assigned_spes"
    t.index ["has_exercise_calculation"], name: "index_assignments_on_has_exercise_calculation"
    t.index ["opens_at"], name: "index_assignments_on_opens_at"
    t.index ["pes_are_assigned"], name: "index_assignments_on_pes_are_assigned"
    t.index ["spes_are_assigned"], name: "index_assignments_on_spes_are_assigned"
    t.index ["student_history_at"], name: "index_assignments_on_student_history_at"
    t.index ["student_uuid", "ecosystem_uuid"], name: "index_assignments_on_student_uuid_and_ecosystem_uuid"
    t.index ["uuid"], name: "index_assignments_on_uuid", unique: true
  end

  create_table "book_container_mappings", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "from_ecosystem_uuid", null: false
    t.uuid "to_ecosystem_uuid", null: false
    t.uuid "from_book_container_uuid", null: false
    t.uuid "to_book_container_uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_book_container_uuid", "from_ecosystem_uuid", "to_ecosystem_uuid"], name: "index_bcms_on_from_bc_uuid_from_eco_uuid_to_eco_uuid_unique", unique: true
    t.index ["from_ecosystem_uuid"], name: "index_book_container_mappings_on_from_ecosystem_uuid"
    t.index ["to_book_container_uuid"], name: "index_book_container_mappings_on_to_book_container_uuid"
    t.index ["to_ecosystem_uuid"], name: "index_book_container_mappings_on_to_ecosystem_uuid"
    t.index ["uuid"], name: "index_book_container_mappings_on_uuid", unique: true
  end

  create_table "course_containers", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "course_uuid", null: false
    t.uuid "student_uuids", null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uuid"], name: "index_course_containers_on_uuid", unique: true
  end

  create_table "courses", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.integer "sequence_number", null: false
    t.uuid "ecosystem_uuid", null: false
    t.uuid "course_excluded_exercise_uuids", null: false, array: true
    t.uuid "course_excluded_exercise_group_uuids", null: false, array: true
    t.uuid "global_excluded_exercise_uuids", null: false, array: true
    t.uuid "global_excluded_exercise_group_uuids", null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "metadata_sequence_number", null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.index ["ecosystem_uuid"], name: "index_courses_on_ecosystem_uuid"
    t.index ["ends_at", "starts_at"], name: "index_courses_on_ends_at_and_starts_at"
    t.index ["metadata_sequence_number"], name: "index_courses_on_metadata_sequence_number", unique: true
    t.index ["updated_at"], name: "index_courses_on_updated_at"
    t.index ["uuid"], name: "index_courses_on_uuid", unique: true
  end

  create_table "ecosystem_exercises", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "ecosystem_uuid", null: false
    t.uuid "exercise_uuid", null: false
    t.uuid "book_container_uuids", null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ecosystem_uuid"], name: "index_ecosystem_exercises_on_ecosystem_uuid"
    t.index ["exercise_uuid", "ecosystem_uuid"], name: "index_eco_exercises_on_exercise_uuid_and_eco_uuid", unique: true
    t.index ["uuid"], name: "index_ecosystem_exercises_on_uuid", unique: true
  end

  create_table "ecosystem_matrix_updates", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "ecosystem_uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "algorithm_names", default: [], null: false, array: true
    t.index ["algorithm_names"], name: "index_ecosystem_matrix_updates_on_algorithm_names", using: :gin
    t.index ["ecosystem_uuid"], name: "index_ecosystem_matrix_updates_on_ecosystem_uuid", unique: true
    t.index ["uuid"], name: "index_ecosystem_matrix_updates_on_uuid", unique: true
  end

  create_table "ecosystem_preparations", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "course_uuid", null: false
    t.uuid "ecosystem_uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_uuid", "ecosystem_uuid"], name: "index_ecosystem_preparations_on_course_uuid_and_ecosystem_uuid"
    t.index ["ecosystem_uuid"], name: "index_ecosystem_preparations_on_ecosystem_uuid"
    t.index ["uuid"], name: "index_ecosystem_preparations_on_uuid", unique: true
  end

  create_table "ecosystems", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.integer "sequence_number", null: false
    t.uuid "exercise_uuids", null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "metadata_sequence_number", null: false
    t.index ["metadata_sequence_number"], name: "index_ecosystems_on_metadata_sequence_number", unique: true
    t.index ["uuid"], name: "index_ecosystems_on_uuid", unique: true
  end

  create_table "exercise_calculations", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "ecosystem_uuid", null: false
    t.uuid "student_uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "algorithm_names", default: [], null: false, array: true
    t.boolean "is_used_in_assignments", null: false
    t.datetime "superseded_at"
    t.index ["algorithm_names"], name: "index_exercise_calculations_on_algorithm_names", using: :gin
    t.index ["ecosystem_uuid"], name: "index_exercise_calculations_on_ecosystem_uuid"
    t.index ["student_uuid", "ecosystem_uuid"], name: "index_exercise_calculations_on_student_uuid_and_ecosystem_uuid"
    t.index ["superseded_at"], name: "index_deletable_exercise_calculations_on_superseded_at", where: "(NOT is_used_in_assignments)"
    t.index ["uuid"], name: "index_exercise_calculations_on_uuid", unique: true
  end

  create_table "exercise_groups", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.integer "response_count", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "trigger_ecosystem_matrix_update", null: false
    t.integer "next_update_response_count", null: false
    t.index ["trigger_ecosystem_matrix_update"], name: "index_exercise_groups_on_trigger_ecosystem_matrix_update"
    t.index ["uuid"], name: "index_exercise_groups_on_uuid", unique: true
  end

  create_table "exercise_pools", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "ecosystem_uuid", null: false
    t.uuid "book_container_uuid", null: false
    t.boolean "use_for_clue", null: false
    t.string "use_for_personalized_for_assignment_types", null: false, array: true
    t.uuid "exercise_uuids", null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_container_uuid"], name: "index_exercise_pools_on_book_container_uuid"
    t.index ["ecosystem_uuid"], name: "index_exercise_pools_on_ecosystem_uuid"
    t.index ["use_for_clue"], name: "index_exercise_pools_on_use_for_clue"
    t.index ["uuid"], name: "index_exercise_pools_on_uuid", unique: true
  end

  create_table "exercises", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "group_uuid", null: false
    t.integer "version", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_uuid", "version"], name: "index_exercises_on_group_uuid_and_version"
    t.index ["uuid"], name: "index_exercises_on_uuid", unique: true
  end

  create_table "responses", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "ecosystem_uuid", null: false
    t.uuid "trial_uuid", null: false
    t.uuid "student_uuid", null: false
    t.uuid "exercise_uuid", null: false
    t.datetime "first_responded_at", null: false
    t.datetime "last_responded_at", null: false
    t.boolean "is_correct", null: false
    t.boolean "is_used_in_clue_calculations", null: false
    t.boolean "is_used_in_exercise_calculations", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_used_in_response_count", null: false
    t.boolean "is_used_in_student_history", null: false
    t.index ["ecosystem_uuid"], name: "index_responses_on_ecosystem_uuid"
    t.index ["exercise_uuid"], name: "index_responses_on_exercise_uuid"
    t.index ["first_responded_at"], name: "index_responses_on_first_responded_at"
    t.index ["is_used_in_clue_calculations"], name: "index_responses_on_is_used_in_clue_calculations"
    t.index ["is_used_in_exercise_calculations"], name: "index_responses_on_is_used_in_exercise_calculations"
    t.index ["is_used_in_response_count"], name: "index_responses_on_is_used_in_response_count"
    t.index ["is_used_in_student_history"], name: "index_responses_on_is_used_in_student_history"
    t.index ["last_responded_at"], name: "index_responses_on_last_responded_at"
    t.index ["student_uuid", "exercise_uuid"], name: "index_responses_on_student_uuid_and_exercise_uuid"
    t.index ["trial_uuid"], name: "index_responses_on_trial_uuid"
    t.index ["uuid"], name: "index_responses_on_uuid", unique: true
  end

  create_table "student_clue_calculations", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "ecosystem_uuid", null: false
    t.uuid "book_container_uuid", null: false
    t.uuid "student_uuid", null: false
    t.string "exercise_uuids", null: false, array: true
    t.text "responses", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "recalculate_at"
    t.string "algorithm_names", default: [], null: false, array: true
    t.index ["algorithm_names"], name: "index_student_clue_calculations_on_algorithm_names", using: :gin
    t.index ["book_container_uuid"], name: "index_student_clue_calculations_on_book_container_uuid"
    t.index ["ecosystem_uuid"], name: "index_student_clue_calculations_on_ecosystem_uuid"
    t.index ["exercise_uuids"], name: "index_student_clue_calculations_on_exercise_uuids", using: :gin
    t.index ["recalculate_at"], name: "index_student_clue_calculations_on_recalculate_at"
    t.index ["student_uuid", "book_container_uuid"], name: "index_s_clue_calc_on_s_uuid_and_bc_uuid", unique: true
    t.index ["uuid"], name: "index_student_clue_calculations_on_uuid", unique: true
  end

  create_table "student_pes", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "algorithm_exercise_calculation_uuid", null: false
    t.uuid "exercise_uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["algorithm_exercise_calculation_uuid", "exercise_uuid"], name: "index_s_pes_on_alg_ex_calc_uuid_and_ex_uuid", unique: true
    t.index ["exercise_uuid"], name: "index_student_pes_on_exercise_uuid"
    t.index ["uuid"], name: "index_student_pes_on_uuid", unique: true
  end

  create_table "students", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "course_uuid", null: false
    t.uuid "course_container_uuids", null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_uuid"], name: "index_students_on_course_uuid"
    t.index ["uuid"], name: "index_students_on_uuid", unique: true
  end

  create_table "teacher_clue_calculations", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "ecosystem_uuid", null: false
    t.uuid "book_container_uuid", null: false
    t.uuid "course_container_uuid", null: false
    t.uuid "student_uuids", null: false, array: true
    t.string "exercise_uuids", null: false, array: true
    t.text "responses", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "algorithm_names", default: [], null: false, array: true
    t.datetime "recalculate_at"
    t.index ["algorithm_names"], name: "index_teacher_clue_calculations_on_algorithm_names", using: :gin
    t.index ["book_container_uuid"], name: "index_teacher_clue_calculations_on_book_container_uuid"
    t.index ["course_container_uuid", "book_container_uuid"], name: "index_t_clue_calc_on_cc_uuid_and_bc_uuid", unique: true
    t.index ["ecosystem_uuid"], name: "index_teacher_clue_calculations_on_ecosystem_uuid"
    t.index ["exercise_uuids"], name: "index_teacher_clue_calculations_on_exercise_uuids", using: :gin
    t.index ["recalculate_at"], name: "index_teacher_clue_calculations_on_recalculate_at"
    t.index ["uuid"], name: "index_teacher_clue_calculations_on_uuid", unique: true
  end

end
