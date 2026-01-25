# frozen_string_literal: true

class REST::CredentialAccountSerializer < REST::AccountSerializer
  attributes :source, :storage_quota

  has_one :role, serializer: REST::RoleSerializer

  def source
    user = object.user

    {
      privacy: user.setting_default_privacy,
      sensitive: user.setting_default_sensitive,
      language: user.setting_default_language,
      note: object.note,
      fields: object.fields.map(&:to_h),
      follow_requests_count: FollowRequest.where(target_account: object).limit(40).count,
      hide_collections: object.hide_collections,
      discoverable: object.discoverable,
      indexable: object.indexable,
      attribution_domains: object.attribution_domains,
      quote_policy: user.setting_default_quote_policy,
    }
  end

  def storage_quota
    return nil unless object.local?

    quota_info = Errordon::StorageQuotaService.quota_for(object)
    {
      used: quota_info[:used],
      quota: quota_info[:quota],
      available: quota_info[:available],
      percentage: quota_info[:percentage],
      can_upload: quota_info[:can_upload],
      used_human: quota_info[:used_human],
      quota_human: quota_info[:quota_human],
    }
  end

  def role
    object.user_role
  end
end
