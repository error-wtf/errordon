# frozen_string_literal: true

class Api::V1::Errordon::TranscodingController < Api::BaseController
  before_action :require_user!
  before_action :set_media_attachment

  # GET /api/v1/errordon/transcoding/:media_id/status
  def status
    render json: transcoding_status
  end

  private

  def set_media_attachment
    @attachment = current_account.media_attachments.find(params[:media_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Media attachment not found' }, status: :not_found
  end

  def transcoding_status
    {
      id: @attachment.id,
      type: @attachment.type,
      processing_status: @attachment.processing_status || 'unknown',
      file_size: @attachment.file_file_size,
      created_at: @attachment.created_at.iso8601,
      variants: @attachment.try(:variants) || {},
      transcoding_enabled: Rails.application.config.x.errordon_transcoding[:enabled],
      estimated_completion: estimate_completion
    }
  end

  def estimate_completion
    return nil unless @attachment.processing_status == 'processing'

    # Rough estimate based on file size (1MB per second processing)
    size_mb = (@attachment.file_file_size || 0) / 1.megabyte.to_f
    seconds_remaining = [size_mb * 2, 10].max.to_i

    Time.current + seconds_remaining.seconds
  end
end
