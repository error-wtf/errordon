# frozen_string_literal: true

class HomeController < ApplicationController
  include WebAppControllerConcern
  before_action :maybe_redirect_to_matrix, only: [:index]

  def index
    expires_in(15.seconds, public: true, stale_while_revalidate: 30.seconds, stale_if_error: 1.day) unless user_signed_in?
  end

  private

  def maybe_redirect_to_matrix
    # Redirect to Matrix Terminal if enabled and user hasn't passed it
    return if user_signed_in?
    return unless ENV.fetch('ERRORDON_MATRIX_LANDING_ENABLED', 'true') == 'true'
    return if session[:matrix_passed]

    # Redirect to static Matrix Terminal (CSP-safe)
    redirect_to '/matrix/index.html', allow_other_host: true
  end
end
