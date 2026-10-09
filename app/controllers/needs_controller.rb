class NeedsController < ApplicationController
  before_action :set_need, only: %i[show edit update destroy]

  def index
    @needs = current_user.needs.includes(:latest_request_draft).order(created_at: :desc)
  end

  def show
    @request_drafts = @need.request_drafts.order(created_at: :desc)
  end

  def new
    @need = current_user.needs.build(categories: Need::DEFAULT_CATEGORIES)
  end

  def create
    @need = current_user.needs.build(need_params)
    if @need.save
      redirect_to @need
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @need.update(need_params)
      redirect_to @need
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @need.destroy
    redirect_to needs_path
  end

  private

  def set_need
    @need = current_user.needs.find(params[:id])
  end

  def need_params
    params.require(:need).permit(:rough_text, :could_offer, :categories, :time_window, :hours)
  end
end
