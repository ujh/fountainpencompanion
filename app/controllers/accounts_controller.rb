class AccountsController < ApplicationController
  before_action :authenticate_user!

  def show
    respond_to do |format|
      format.html
      format.jsonapi { render jsonapi: current_user, **show_options }
    end
  end

  def update
    successful = current_user.update(accounts_params)
    if successful && current_user.saved_change_to_blurb?
      AfterUserSaved.perform_async(current_user.id)
    end
    respond_to do |format|
      format.html do
        if successful
          redirect_to account_path
        else
          render :edit
        end
      end
      format.json { head :ok }
      format.jsonapi { render jsonapi: current_user }
    end
  end

  private

  def show_options
    options = {}
    if params[:include].present?
      options[:include] = params[:include].split(",").map { |i| i.strip.to_sym }
    end
    options
  end

  PREFERENCE_KEYS = %w[
    collected_inks_table_hidden_fields
    collected_inks_cards_hidden_fields
    collected_pens_table_hidden_fields
    collected_pens_cards_hidden_fields
    currently_inked_table_hidden_fields
    currently_inked_cards_hidden_fields
    dashboard_widgets
    usage_visualization_range
    usage_visualization_speed
  ].freeze

  def accounts_params
    raw = (params["_jsonapi"] || params).require(:user)
    raw_prefs = raw[:preferences]
    permitted = raw.except(:preferences).permit(:name, :blurb, :time_zone)
    if raw_prefs.present?
      merged = current_user.preferences.dup
      raw_prefs.each do |key, value|
        next unless PREFERENCE_KEYS.include?(key.to_s)

        if value.nil?
          merged.delete(key.to_s)
        else
          merged[key.to_s] = value.as_json
        end
      end
      permitted[:preferences] = merged
    end

    permitted
  end
end
