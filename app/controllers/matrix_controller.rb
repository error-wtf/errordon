# frozen_string_literal: true

class MatrixController < ApplicationController
  skip_before_action :require_functional!

  def index
    # Redirect to static Matrix Terminal (CSP-safe)
    redirect_to '/matrix/index.html', allow_other_host: true
  end

  # Bot protection: Set session flag when user completes terminal challenge
  def pass
    session[:matrix_passed] = true
    session[:matrix_passed_at] = Time.now.utc.to_i
    head :ok
  end
end
