# frozen_string_literal: true

class AddErrordonTranscodingFields < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      # Add transcoding status and variants to media_attachments
      add_column :media_attachments, :processing_status, :string, default: 'pending'
      add_column :media_attachments, :variants, :jsonb, default: {}
      add_column :media_attachments, :original_size, :bigint
      add_column :media_attachments, :transcoded_size, :bigint

      add_index :media_attachments, :processing_status, algorithm: :concurrently

      # Add quota tracking to accounts
      add_column :accounts, :media_storage_used, :bigint, default: 0
      add_column :accounts, :daily_upload_size, :bigint, default: 0
      add_column :accounts, :daily_upload_reset_at, :datetime
    end
  end
end
