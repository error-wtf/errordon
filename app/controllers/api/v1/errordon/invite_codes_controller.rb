# frozen_string_literal: true

class Api::V1::Errordon::InviteCodesController < Api::BaseController
  before_action :require_admin!
  before_action :set_invite, only: [:destroy, :deactivate]

  # GET /api/v1/errordon/invite_codes
  def index
    @invites = Invite.where(user: current_user)
                     .or(Invite.where(user_id: nil))
                     .order(created_at: :desc)
                     .page(params[:page])
                     .per(25)

    render json: @invites, each_serializer: InviteSerializer
  end

  # POST /api/v1/errordon/invite_codes
  def create
    @invite = Invite.new(invite_params)
    @invite.user = current_user

    if @invite.save
      render json: @invite, serializer: InviteSerializer, status: :created
    else
      render json: { error: @invite.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/errordon/invite_codes/:id
  def destroy
    @invite.destroy!
    render json: { success: true }
  end

  # POST /api/v1/errordon/invite_codes/:id/deactivate
  def deactivate
    @invite.update!(expires_at: Time.now.utc)
    render json: @invite, serializer: InviteSerializer
  end

  private

  def require_admin!
    forbidden unless current_user&.role&.can?(:manage_invites)
  end

  def set_invite
    @invite = Invite.find(params[:id])
  end

  def invite_params
    params.permit(:max_uses, :expires_at, :autofollow, :comment)
  end

  class InviteSerializer < ActiveModel::Serializer
    attributes :id, :code, :uses, :max_uses, :expires_at, :autofollow, :comment, :created_at, :expired

    def expired
      object.expired?
    end

    def code
      object.code
    end
  end
end
