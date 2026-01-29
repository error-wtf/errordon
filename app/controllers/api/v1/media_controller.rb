# frozen_string_literal: true

class Api::V1::MediaController < Api::BaseController
  before_action -> { doorkeeper_authorize! :write, :'write:media' }
  before_action :require_user!
  before_action :set_media_attachment, except: [:create, :destroy]
  before_action :check_processing, except: [:create, :destroy]

  def show
    render json: @media_attachment, serializer: REST::MediaAttachmentSerializer, status: status_code_for_media_attachment
  end

  def create
    @media_attachment = current_account.media_attachments.create!(media_attachment_params)
    
    # Errordon: Queue NSFW check if enabled
    enqueue_nsfw_check(@media_attachment)
    
    render json: @media_attachment, serializer: REST::MediaAttachmentSerializer
  rescue Paperclip::Errors::NotIdentifiedByImageMagickError
    render json: file_type_error, status: 422
  rescue Paperclip::Error => e
    Rails.logger.error "#{e.class}: #{e.message}"
    render json: processing_error, status: 500
  end

  def update
    @media_attachment.update!(updateable_media_attachment_params)
    render json: @media_attachment, serializer: REST::MediaAttachmentSerializer, status: status_code_for_media_attachment
  end

  def destroy
    @media_attachment = current_account.media_attachments.find(params[:id])

    return render json: in_usage_error, status: 422 unless @media_attachment.status_id.nil?

    @media_attachment.destroy
    render_empty
  end

  private

  def status_code_for_media_attachment
    @media_attachment.not_processed? ? 206 : 200
  end

  def set_media_attachment
    @media_attachment = current_account.media_attachments.where(status_id: nil).find(params[:id])
  end

  def check_processing
    render json: processing_error, status: 422 if @media_attachment.processing_failed?
  end

  def media_attachment_params
    params.permit(:file, :thumbnail, :description, :focus)
  end

  def updateable_media_attachment_params
    params.permit(:thumbnail, :description, :focus)
  end

  def file_type_error
    { error: 'File type of uploaded media could not be verified' }
  end

  def processing_error
    { error: 'Error processing thumbnail for uploaded media' }
  end

  def in_usage_error
    { error: 'Media attachment is currently used by a status' }
  end

  # Errordon: NSFW-Protect AI check
  def enqueue_nsfw_check(media_attachment)
    return unless defined?(NsfwProtectConfig) && NsfwProtectConfig.enabled?
    return unless media_attachment.image? || media_attachment.video?
    
    # Get client IP for audit logging
    ip_address = request.remote_ip
    
    # Queue the NSFW check as a background job
    Errordon::NsfwCheckWorker.perform_async(media_attachment.id, ip_address)
    Rails.logger.info "[NSFW-Protect] Queued check for media #{media_attachment.id}"
  rescue StandardError => e
    # Don't block upload if NSFW check fails to queue
    Rails.logger.error "[NSFW-Protect] Failed to queue check: #{e.message}"
  end
end
