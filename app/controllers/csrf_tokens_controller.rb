class CsrfTokensController < ApplicationController
  def show
    # Run Devise's strategies (e.g. remember-me) before generating the token.
    # Signing in via remember-me rotates the session's CSRF token, which would
    # otherwise invalidate the token returned here on the next request.
    user_signed_in?

    response.headers["Cache-Control"] = "no-store"
    render json: { token: form_authenticity_token }
  end
end
