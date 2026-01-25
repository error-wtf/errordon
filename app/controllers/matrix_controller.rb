# frozen_string_literal: true

class MatrixController < ApplicationController
  skip_before_action :require_functional!

  def index
    expires_in(1.hour, public: true, stale_while_revalidate: 1.day) unless user_signed_in?
  end
end
