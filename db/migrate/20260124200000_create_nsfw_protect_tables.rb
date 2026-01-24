# frozen_string_literal: true

class CreateNsfwProtectTables < ActiveRecord::Migration[7.1]
  def change
    # NSFW-Protect configuration table (instance-wide settings)
    create_table :nsfw_protect_configs do |t|
      t.boolean :enabled, default: false, null: false
      t.boolean :porn_detection_enabled, default: true, null: false
      t.boolean :hate_detection_enabled, default: true, null: false
      t.boolean :illegal_detection_enabled, default: true, null: false
      t.boolean :auto_delete_violations, default: true, null: false
      t.boolean :instance_freeze_enabled, default: true, null: false
      t.string :admin_alert_email
      t.string :ollama_endpoint, default: 'http://localhost:11434'
      t.string :ollama_vision_model, default: 'llava'
      t.string :ollama_text_model, default: 'llama3'
      t.integer :instance_alarm_threshold, default: 10, null: false
      t.boolean :instance_frozen, default: false, null: false
      t.datetime :instance_frozen_at
      t.timestamps
    end

    # NSFW-Protect strikes/violations table
    create_table :nsfw_protect_strikes do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :status, foreign_key: { on_delete: :nullify }
      t.references :media_attachment, foreign_key: { on_delete: :nullify }
      t.references :report, foreign_key: { on_delete: :nullify }
      t.integer :strike_type, null: false, default: 0
      t.integer :severity, null: false, default: 1
      t.inet :ip_address
      t.text :ai_analysis_result
      t.float :ai_confidence
      t.string :ai_category
      t.text :ai_reason
      t.boolean :resolved, default: false, null: false
      t.references :resolved_by, foreign_key: { to_table: :accounts, on_delete: :nullify }
      t.datetime :resolved_at
      t.text :resolution_notes
      t.timestamps

      t.index [:account_id, :resolved], name: 'index_nsfw_strikes_on_account_and_resolved'
      t.index [:created_at], name: 'index_nsfw_strikes_on_created_at'
      t.index [:strike_type], name: 'index_nsfw_strikes_on_type'
    end

    # NSFW-Protect freeze history
    create_table :nsfw_protect_freezes do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :nsfw_protect_strike, foreign_key: { on_delete: :nullify }
      t.integer :freeze_type, null: false, default: 0
      t.integer :duration_hours, null: false
      t.datetime :started_at, null: false
      t.datetime :ends_at
      t.boolean :permanent, default: false, null: false
      t.boolean :active, default: true, null: false
      t.inet :ip_address
      t.timestamps

      t.index [:account_id, :active], name: 'index_nsfw_freezes_on_account_and_active'
      t.index [:ends_at], name: 'index_nsfw_freezes_on_ends_at'
    end

    # Enhanced invite codes for Errordon
    create_table :errordon_invite_codes do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :code, null: false
      t.integer :uses, default: 0, null: false
      t.integer :max_uses, default: 3, null: false
      t.datetime :expires_at
      t.boolean :active, default: true, null: false
      t.timestamps

      t.index [:code], unique: true, name: 'index_errordon_invite_codes_on_code'
      t.index [:account_id, :active], name: 'index_errordon_invites_on_account_and_active'
    end

    # Add NSFW-Protect fields to accounts
    add_column :accounts, :nsfw_strike_count, :integer, default: 0, null: false
    add_column :accounts, :nsfw_porn_strikes, :integer, default: 0, null: false
    add_column :accounts, :nsfw_hate_strikes, :integer, default: 0, null: false
    add_column :accounts, :nsfw_frozen_until, :datetime
    add_column :accounts, :nsfw_permanent_freeze, :boolean, default: false, null: false
    add_column :accounts, :nsfw_ever_frozen, :boolean, default: false, null: false
    add_column :accounts, :nsfw_last_strike_ip, :inet

    add_index :accounts, :nsfw_frozen_until, name: 'index_accounts_on_nsfw_frozen_until'
    add_index :accounts, :nsfw_permanent_freeze, name: 'index_accounts_on_nsfw_permanent_freeze'

    # Add age verification to users
    add_column :users, :age_verified, :boolean, default: false, null: false
    add_column :users, :terms_accepted_at, :datetime
    add_column :users, :privacy_accepted_at, :datetime
    add_column :users, :rules_accepted_at, :datetime
    add_column :users, :errordon_invite_code_id, :bigint

    add_foreign_key :users, :errordon_invite_codes, column: :errordon_invite_code_id, on_delete: :nullify
  end
end
