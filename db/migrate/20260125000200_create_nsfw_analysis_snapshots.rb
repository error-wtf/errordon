# frozen_string_literal: true

class CreateNsfwAnalysisSnapshots < ActiveRecord::Migration[7.1]
  def change
    create_table :nsfw_analysis_snapshots do |t|
      t.references :media_attachment, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :nsfw_protect_strike, foreign_key: { on_delete: :nullify }
      
      # AI Analysis Results
      t.string :ai_category, null: false           # SAFE, PORN, HATE, ILLEGAL, CSAM, REVIEW
      t.float :ai_confidence, null: false          # 0.0 - 1.0
      t.text :ai_reason
      t.text :ai_raw_response
      
      # Metadata
      t.string :media_type                         # image, video
      t.integer :media_file_size
      t.string :media_content_type
      
      # Retention management
      t.boolean :violation_detected, default: false, null: false
      t.boolean :marked_for_deletion, default: false, null: false
      t.datetime :delete_after                     # When this snapshot should be deleted
      
      t.timestamps
      
      t.index [:violation_detected, :delete_after], name: 'index_nsfw_snapshots_cleanup'
      t.index [:account_id, :created_at], name: 'index_nsfw_snapshots_account_timeline'
      t.index [:ai_category], name: 'index_nsfw_snapshots_category'
    end
  end
end
