require "rails_helper"

RSpec.describe "Home", type: :request do
  it "shows the pitch and the fictional example to visitors" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Lift to the recycling centre", "Swap ideas", "https://unityoffers.com", "Try it free")
  end

  it "sends a signed-in member to their needs" do
    sign_in_as(create(:user))
    get root_path
    expect(response.body).to include("Go to my needs")
  end
end
