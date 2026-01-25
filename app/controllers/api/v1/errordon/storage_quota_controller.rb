# frozen_string_literal: true

class Api::V1::Errordon::StorageQuotaController < Api::BaseController
  before_action :require_user!

  def show
    quota_info = Errordon::StorageQuotaService.quota_for(current_account)
    render json: {
      quota: quota_info[:quota],
      used: quota_info[:used],
      available: quota_info[:available],
      percentage: quota_info[:percentage],
      can_upload: quota_info[:can_upload],
      quota_human: quota_info[:quota_human],
      used_human: quota_info[:used_human],
      available_human: quota_info[:available_human]
    }
  end
end
