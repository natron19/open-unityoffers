require "rails_helper"

RSpec.describe RequestDraft, type: :model do
  describe "validations" do
    it "is valid with the factory attributes" do
      expect(build(:request_draft)).to be_valid
    end

    it "requires a need" do
      expect(build(:request_draft, need: nil)).not_to be_valid
    end

    it "accepts every known status and rejects others" do
      RequestDraft::STATUSES.each { |s| expect(build(:request_draft, status: s)).to be_valid }
      expect(build(:request_draft, status: "unknown")).not_to be_valid
    end

    it "lists the statuses and the hard-rule limits" do
      expect(RequestDraft::STATUSES).to eq(%w[pending completed failed])
      expect(RequestDraft::TITLE_MAX_CHARS).to eq(80)
      expect(RequestDraft::SWAP_TERM_COUNT).to eq(2..3)
    end
  end

  describe "associations and defaults" do
    it "has a user through its need" do
      draft = create(:request_draft)
      expect(draft.user).to eq(draft.need.user)
    end

    it "starts pending with no swap terms" do
      draft = RequestDraft.create!(need: create(:need))
      expect(draft.status).to eq("pending")
      expect(draft.swap_terms).to eq([])
    end
  end

  describe "#stale?" do
    it "is true when the need changed after the draft" do
      draft = create(:request_draft, :completed, generated_at: 1.hour.ago)
      draft.need.update!(time_window: "Next Sunday")
      expect(draft.stale?).to be(true)
    end

    it "is false when the draft is newer than the need" do
      draft = create(:request_draft, :completed, generated_at: 1.minute.from_now)
      expect(draft.stale?).to be(false)
    end
  end

  describe "#to_markdown" do
    it "includes the request, the question, what changed, the swap terms and the member's words" do
      draft = create(:request_draft, :completed)
      md = draft.to_markdown
      expect(md).to include("# Request: Lift to the recycling centre", "**Category:** Rides", draft.description)
      expect(md).to include("_One detail to add:_ Which recycling centre is it?")
      expect(md).to include("## What changed from your words", draft.what_changed)
      expect(md).to include("1. You drive me to the recycling centre one Saturday; I hem two things for you.")
      expect(md).to include("   - You give: Hemming two items", "   - They give: The lift")
      expect(md).to include("> #{draft.need.rough_text}", "_Time it might take:_ About 2 hours")
      expect(md).to include("AI-generated")
    end

    it "leaves out the question when there is none" do
      draft = create(:request_draft, :completed, missing_detail_question: nil)
      expect(draft.to_markdown).not_to include("One detail to add")
    end

    it "names the file after the title" do
      draft = create(:request_draft, :completed)
      expect(draft.markdown_filename).to eq("lift-to-the-recycling-centre-request.md")
    end
  end
end
