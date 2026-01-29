# frozen_string_literal: true

class Auth::ConfirmationsController < Devise::ConfirmationsController
  include Auth::CaptchaConcern

  layout 'auth'

  before_action :set_confirmation_user!, only: [:show, :confirm_captcha]
  before_action :redirect_confirmed_user, if: :signed_in_confirmed_user?

  before_action :extend_csp_for_captcha!, only: [:show, :confirm_captcha]
  before_action :require_captcha_if_needed!, only: [:show]

  skip_before_action :check_self_destruct!
  skip_before_action :require_functional!

  def show
    old_session_values = session.to_hash
    reset_session
    session.update old_session_values.except('session_id')

    # Errordon: Auto-sign in user after confirmation
    if @confirmation_user && !@confirmation_user.confirmed?
      # User will be confirmed by Devise's super call
      # We'll sign them in via after_confirmation_path_for
    end

    super
  end

  def new
    super

    resource.email = current_user.unconfirmed_email || current_user.email if user_signed_in?
  end

  def confirm_captcha
    check_captcha! do |message|
      flash.now[:alert] = message
      render :captcha
      return
    end

    show
  end

  def redirect_to_app?
    truthy_param?(:redirect_to_app)
  end

  helper_method :redirect_to_app?

  private

  def require_captcha_if_needed!
    render :captcha if captcha_required?
  end

  def set_confirmation_user!
    # We need to reimplement looking up the user because
    # Devise::ConfirmationsController#show looks up and confirms in one
    # step.
    confirmation_token = params[:confirmation_token]
    return if confirmation_token.nil?

    @confirmation_user = User.find_first_by_auth_conditions(confirmation_token: confirmation_token)
  end

  def captcha_user_bypass?
    @confirmation_user.nil? || @confirmation_user.confirmed?
  end

  def redirect_confirmed_user
    redirect_to(current_user.approved? ? root_path : edit_user_registration_path)
  end

  def signed_in_confirmed_user?
    user_signed_in? && current_user.confirmed? && current_user.unconfirmed_email.blank?
  end

  def after_resending_confirmation_instructions_path_for(_resource_name)
    if user_signed_in?
      if current_user.confirmed? && current_user.approved?
        edit_user_registration_path
      else
        auth_setup_path
      end
    else
      new_user_session_path
    end
  end

  def after_confirmation_path_for(_resource_name, user)
    # Errordon: Auto-sign in user after email confirmation
    # This ensures users are logged in immediately after confirming their email
    if user.approved? && !user_signed_in?
      sign_in(user)
      flash[:notice] = I18n.t('devise.confirmations.confirmed_and_signed_in', default: 'Your email has been confirmed. You are now signed in!')
      return web_url('start')
    end

    # Original behavior for app redirects (only if explicitly requested AND user came from app)
    if user.created_by_application && redirect_to_app?
      # Try app redirect, but provide fallback
      app_uri = user.created_by_application.confirmation_redirect_uri
      if app_uri.present?
        return app_uri
      end
    end

    # Fallback: redirect to web interface
    if user_signed_in?
      web_url('start')
    elsif user.approved?
      # Sign in and redirect
      sign_in(user)
      web_url('start')
    else
      # User needs approval
      new_user_session_path
    end
  end
end
