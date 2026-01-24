# frozen_string_literal: true

class AddErrordonShrunkToMediaAttachments < ActiveRecord::Migration[7.1]
  def change
    add_column :media_attachments, :errordon_shrunk, :boolean, default: false, null: false
    add_column :media_attachments, :errordon_shrunk_at, :datetime
    add_column :media_attachments, :errordon_original_size, :bigint

    add_index :media_attachments, [:type, :errordon_shrunk, :created_at],
              name: 'index_media_attachments_on_video_cleanup',
              where: "type = 2" # video type
  end
end
