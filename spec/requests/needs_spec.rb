require "rails_helper"

RSpec.describe "Needs", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }
  let(:need)  { create(:need, user: user) }

  let(:valid_params) do
    { need: { rough_text: "Could use a hand moving a sofa up two flights of stairs.", could_offer: "",
              categories: "Tools, Rides, Hours", time_window: "Sunday morning", hours: "1" } }
  end

  context "when not signed in" do
    it "redirects every page to sign in" do
      get needs_path
      expect(response).to redirect_to(sign_in_path)
      get dashboard_path
      expect(response).to redirect_to(sign_in_path)
      post needs_path, params: valid_params
      expect(response).to redirect_to(sign_in_path)
    end
  end

  context "when signed in" do
    before { sign_in_as(user) }

    it "shows the dashboard as My needs with only the user's own needs" do
      create(:need, user: user, rough_text: "Mine: a ladder for the gutters")
      create(:need, user: other, rough_text: "Someone else needs a lift")
      get dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My needs", "Mine: a ladder for the gutters")
      expect(response.body).not_to include("Someone else needs a lift")
    end

    it "shows the latest draft's title and category on the dashboard" do
      create(:request_draft, :completed, need: need)
      get needs_path
      expect(response.body).to include("Lift to the recycling centre", "Rides")
    end

    it "shows an empty state with no needs" do
      get needs_path
      expect(response.body).to include("Write your first need")
    end

    it "renders the new form with the labels the UI journey fills and the default categories" do
      get new_need_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("What do you need?", "What could you offer back?", "Your board&#39;s categories",
                                       "When", "Rough hours", Need::DEFAULT_CATEGORIES)
    end

    it "creates a need and redirects to it" do
      expect { post needs_path, params: valid_params }.to change(user.needs, :count).by(1)
      expect(response).to redirect_to(need_path(Need.last))
      expect(Need.last.hours).to eq(1)
    end

    it "re-renders the form with 422 on invalid input" do
      expect {
        post needs_path, params: { need: valid_params[:need].merge(rough_text: "help") }
      }.not_to change(Need, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "shows the need with the Write my request button" do
      get need_path(need)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(need.rough_text, "Write my request")
    end

    it "updates a need" do
      patch need_path(need), params: { need: { time_window: "Next Sunday" } }
      expect(response).to redirect_to(need_path(need))
      expect(need.reload.time_window).to eq("Next Sunday")
    end

    it "rejects an invalid update with 422" do
      patch need_path(need), params: { need: { categories: "Rides" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "deletes a need" do
      need
      expect { delete need_path(need) }.to change(Need, :count).by(-1)
      expect(response).to redirect_to(needs_path)
    end
  end

  # open-base's ApplicationController answers RecordNotFound with a redirect to root and an alert.
  context "when signed in as a different user" do
    before { sign_in_as(other) }

    it "cannot see, edit, update, or delete the need" do
      get need_path(need)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That record could not be found.")
      get edit_need_path(need)
      expect(response).to redirect_to(root_path)
      patch need_path(need), params: { need: { time_window: "Hijacked" } }
      expect(response).to redirect_to(root_path)
      expect { delete need_path(need) }.not_to change(Need, :count)
      expect(response).to redirect_to(root_path)
      expect(need.reload.time_window).not_to eq("Hijacked")
    end
  end
end
