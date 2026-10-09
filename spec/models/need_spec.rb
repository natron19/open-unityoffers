require "rails_helper"

RSpec.describe Need, type: :model do
  describe "validations" do
    it "is valid with the factory attributes" do
      expect(build(:need)).to be_valid
    end

    it "requires a user" do
      expect(build(:need, user: nil)).not_to be_valid
    end

    it "requires rough_text of 10 to 600 characters" do
      expect(build(:need, rough_text: "")).not_to be_valid
      expect(build(:need, rough_text: "help")).not_to be_valid
      expect(build(:need, rough_text: "a" * 601)).not_to be_valid
      expect(build(:need, rough_text: "need help pls")).to be_valid
    end

    it "makes could_offer, time_window and hours optional" do
      expect(build(:need, could_offer: "", time_window: "", hours: nil)).to be_valid
    end

    it "caps could_offer and time_window" do
      expect(build(:need, could_offer: "a" * 301)).not_to be_valid
      expect(build(:need, time_window: "a" * 121)).not_to be_valid
    end

    it "accepts whole hours from 1 to 40" do
      expect(build(:need, hours: 0)).not_to be_valid
      expect(build(:need, hours: 41)).not_to be_valid
      expect(build(:need, hours: 1.5)).not_to be_valid
      expect(build(:need, hours: 40)).to be_valid
    end

    it "requires 2 to 12 categories of at most 40 characters" do
      expect(build(:need, categories: "")).not_to be_valid
      expect(build(:need, categories: "Rides")).not_to be_valid
      expect(build(:need, categories: (1..13).map { |i| "Cat #{i}" }.join(", "))).not_to be_valid
      expect(build(:need, categories: "Rides, #{'a' * 41}")).not_to be_valid
      expect(build(:need, categories: "Rides, Meals")).to be_valid
    end
  end

  describe "#category_list" do
    it "splits on commas and new lines, trims, and drops blanks and duplicates" do
      need = build(:need, categories: " Rides,meals\nRIDES, , Garden ")
      expect(need.category_list).to eq(%w[Rides meals Garden])
    end

    it "is normalized on save" do
      need = create(:need, categories: "Rides,  Meals,\nGarden")
      expect(need.categories).to eq("Rides, Meals, Garden")
    end
  end

  describe "#category_named" do
    it "returns the list entry regardless of case and spacing, or nil" do
      need = build(:need, categories: "Rides, Desk space")
      expect(need.category_named("desk  SPACE")).to eq("Desk space")
      expect(need.category_named("Pets")).to be_nil
      expect(need.category_named(nil)).to be_nil
    end
  end

  describe "#ai_variables" do
    it "sends the member's words, the list and fallbacks, and nothing about the member" do
      need = build(:need, could_offer: "", time_window: "", hours: nil, categories: "Rides, Meals")
      expect(need.ai_variables).to eq(
        rough_text:     need.rough_text,
        could_offer:    "Nothing listed",
        category_names: "Rides, Meals",
        time_window:    "Not stated",
        hours:          "Not stated"
      )
    end

    it "phrases the hours" do
      expect(build(:need, hours: 1).ai_variables[:hours]).to eq("about 1 hour")
      expect(build(:need, hours: 3).ai_variables[:hours]).to eq("about 3 hours")
    end
  end

  describe "associations" do
    it "destroys its drafts and finds the latest one" do
      need  = create(:need)
      old   = create(:request_draft, :completed, need: need, generated_at: 2.hours.ago)
      newer = create(:request_draft, :completed, need: need, generated_at: 1.hour.ago)
      expect(need.latest_request_draft).to eq(newer)
      expect { need.destroy }.to change(RequestDraft, :count).by(-2)
      expect(RequestDraft.exists?(old.id)).to be(false)
    end
  end
end
