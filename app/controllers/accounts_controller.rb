class AccountsController < ApplicationController
  before_action :authenticate_user!

  rescue_from ActionController::BadRequest do
    head :bad_request
  end

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
      format.json do
        if successful
          head :ok
        else
          render json: { errors: current_user.errors.full_messages }, status: :unprocessable_content
        end
      end
      format.jsonapi do
        if successful
          render jsonapi: current_user
        else
          render jsonapi_errors: current_user.errors, status: :unprocessable_content
        end
      end
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
    source = params[:_jsonapi].is_a?(ActionController::Parameters) ? params[:_jsonapi] : params
    raw = source.require(:user)
    raise ActionController::BadRequest unless raw.is_a?(ActionController::Parameters)

    raw_prefs = raw[:preferences]
    permitted = raw.except(:preferences).permit(:name, :blurb, :time_zone)
    if raw_prefs.present?
      raise ActionController::BadRequest unless raw_prefs.is_a?(ActionController::Parameters)

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
