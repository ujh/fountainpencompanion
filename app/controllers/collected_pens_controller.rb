class CollectedPensController < ApplicationController
  before_action :authenticate_user!
  before_action :retrieve_collected_pens

  def index
  end

  private

  def retrieve_collected_pens
    @collected_pens = current_user.collected_pens.order('brand, model')
  end
end
