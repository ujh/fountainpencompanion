# Option B: lets a signed-in user link their Patreon account ("Connect
# Patreon") so their patron status is recognized without relying on a matching
# email. The link stores the authoritative patreon_user_id on the user; the
# daily SyncPatreonPatrons job then keeps the flag in sync going forward.
class PatreonConnectionsController < ApplicationController
  before_action :authenticate_user!

  def connect
    state = SecureRandom.hex(24)
    session[:patreon_oauth_state] = state
    redirect_to PatreonClient.authorize_url(redirect_uri: patreon_callback_url, state: state),
                allow_other_host: true
  end

  def callback
    return reject("Patreon connection was cancelled.") if params[:error].present?
    return reject("Patreon connection expired. Please try again.") unless valid_state?

    token = PatreonClient.exchange_code(params[:code], redirect_uri: patreon_callback_url)
    identity = PatreonClient.new(token["access_token"]).identity
    link_account(identity)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    reject("That Patreon account is already linked to another Fountain Pen Companion account.")
  rescue Faraday::Error, JSON::ParserError
    # Faraday::Error covers HTTP failures; JSON::ParserError covers a 200 that
    # carries a non-JSON body (e.g. an HTML error page served under load).
    reject("Couldn't reach Patreon. Please try again.")
  end

  def destroy
    # Clear the link only; the daily sync re-evaluates the patron flag (it may
    # still match by email, or revoke it on the next run if appropriate).
    current_user.update!(patreon_user_id: nil, patreon_email: nil)
    redirect_to account_path, notice: "Patreon account disconnected."
  end

  private

  def valid_state?
    state = session.delete(:patreon_oauth_state)
    params[:state].present? &&
      ActiveSupport::SecurityUtils.secure_compare(params[:state], state.to_s)
  end

  def link_account(identity)
    granted = entitled?(identity)
    attrs = { patreon_user_id: identity.patreon_user_id, patreon_email: identity.email }
    if granted
      attrs.merge!(patreon_status: "active_patron", patreon_synced_at: Time.current)
      # Mirror SyncPatreonPatrons: never overwrite an admin-pinned ("manual")
      # patron, otherwise we'd make them eligible for auto-revocation later.
      unless current_user.patron_source == "manual"
        attrs.merge!(patron: true, patron_source: "patreon")
      end
    end
    current_user.update!(attrs)
    # Tell the admin to mark the badge benefit delivered (no-op unless this
    # actually granted patron via Patreon and hasn't been reported yet).
    PatreonBadgeReporter.call([current_user]) if granted
    if granted
      redirect_to account_path,
                  notice: "Patreon connected — your patron status is active. Thank you!"
    else
      redirect_to account_path,
                  notice: "Patreon connected, but no active membership was found on your account."
    end
  end

  def entitled?(identity)
    campaign_id = ENV["PATREON_CAMPAIGN_ID"]
    campaign_id.present? &&
      identity.memberships.any? { |m| m.campaign_id == campaign_id && m.active? }
  end

  def reject(message)
    redirect_to account_path, alert: message
  end
end
