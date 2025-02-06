class UsageRecordsController < ApplicationController
  before_action :authenticate_user!
  before_action :retrieve_currently_inked, only: [:create]

  add_breadcrumb "Currently inked", :currently_inked_index_path
  add_breadcrumb "Usage records", :usage_records_path

  def index
    @usage_records =
      current_user
        .usage_records
        .includes(currently_inked: %i[collected_ink collected_pen])
        .order("used_on DESC, currently_inked_id")
    respond_to do |format|
      format.html { @usage_records = @usage_records.page(params[:page]) }
      format.csv do
        send_data @usage_records.to_csv, type: "text/csv", filename: "usage_records.csv"
      end
    end
  end

  def create
    @currently_inked.usage_records.find_or_create_by(used_on: Date.current) if @currently_inked
    head :created
  end

  def destroy
    @usage_record = current_user.usage_records.find(params[:id])
    @usage_record.destroy
    redirect_to usage_records_path
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def retrieve_currently_inked
    @currently_inked = current_user.currently_inkeds.find_by(id: params[:currently_inked_id])
  end
end
