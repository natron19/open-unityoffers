require "rails_helper"

RSpec.describe "RequestDrafts", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }
  let(:need)  { create(:need, user: user) }

  let(:valid_result) do
    {
      "request" => {
        "title"       => "Lift to the recycling centre",
        "description" => "I could use a lift to the recycling centre with some boxes. Any Saturday this month works.",
        "category"    => "rides"
      },
      "what_changed" => "I dropped the apology and kept the boxes and the Saturday.",
      "missing_detail_question" => "Which recycling centre is it?",
      "swap_terms" => [
        { "you_give" => "Hemming two items", "they_give" => "A Saturday lift",
          "one_line" => "You drive me to the recycling centre one Saturday; I hem two things for you." },
        { "you_give" => "Nothing this time", "they_give" => "The lift",
          "one_line" => "You give me a lift one Saturday, and nothing is expected back." }
      ]
    }
  end

  def with_request(changes)
    valid_result.merge("request" => valid_result["request"].merge(changes))
  end

  def with_term(changes)
    valid_result.merge("swap_terms" => [ valid_result["swap_terms"][0].merge(changes), valid_result["swap_terms"][1] ])
  end

  def write_draft
    post need_request_drafts_path(need)
  end

  # UUID primary keys: .last would order by a random id.
  def latest_draft
    RequestDraft.order(:created_at).last
  end

  describe "POST /needs/:need_id/drafts" do
    context "when not signed in" do
      it "redirects to sign in" do
        write_draft
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in as the owner with a valid response" do
      before do
        sign_in_as(user)
        gemini_returns(valid_result.to_json)
      end

      it "calls GeminiService with the template and the need's variables" do
        expect(GeminiService).to receive(:generate).with(
          template:  "unityoffers_request_v1",
          variables: {
            rough_text:     need.rough_text,
            could_offer:    need.could_offer,
            category_names: Need::DEFAULT_CATEGORIES,
            time_window:    need.time_window,
            hours:          "about 2 hours"
          }
        ).and_return(valid_result.to_json)
        write_draft
      end

      it "creates a completed draft with the parsed fields, the list's spelling of the category, and the raw response" do
        expect { write_draft }.to change(RequestDraft, :count).by(1)
        draft = latest_draft
        expect(draft.status).to eq("completed")
        expect(draft.gemini_raw).to eq(valid_result.to_json)
        expect(draft.title).to eq("Lift to the recycling centre")
        expect(draft.category).to eq("Rides")
        expect(draft.missing_detail_question).to eq("Which recycling centre is it?")
        expect(draft.swap_terms.size).to eq(2)
        expect(draft.swap_terms.first.keys).to match_array(%w[you_give they_give one_line])
        expect(draft.generated_at).to be_present
      end

      it "redirects to the result page" do
        write_draft
        expect(response).to redirect_to(need_request_draft_path(need, latest_draft))
      end

      it "accepts a response wrapped in a ```json fence" do
        gemini_returns("```json\n#{valid_result.to_json}\n```")
        write_draft
        expect(latest_draft.status).to eq("completed")
      end

      it "accepts a null or absent missing_detail_question, and three swap terms" do
        gemini_returns(valid_result.merge("missing_detail_question" => nil).to_json)
        write_draft
        expect(latest_draft).to have_attributes(status: "completed", missing_detail_question: nil)

        three = valid_result.except("missing_detail_question")
                            .merge("swap_terms" => valid_result["swap_terms"] + [ valid_result["swap_terms"][0] ])
        gemini_returns(three.to_json)
        write_draft
        expect(latest_draft).to have_attributes(status: "completed", missing_detail_question: nil)
        expect(latest_draft.swap_terms.size).to eq(3)
      end

      it "accepts a title of exactly 80 characters" do
        gemini_returns(with_request("title" => "a" * 80).to_json)
        write_draft
        expect(latest_draft.status).to eq("completed")
      end
    end

    context "when the response cannot be used" do
      before { sign_in_as(user) }

      def expect_failed(text, reason)
        gemini_returns(text)
        expect { write_draft }.to change(RequestDraft, :count).by(1)
        draft = latest_draft
        expect(draft.status).to eq("failed")
        expect(draft.gemini_raw).to eq(text)
        expect(draft.failure_reason).to include(reason)
        expect(response).to redirect_to(need_request_draft_path(need, draft))
      end

      it("fails text that is not JSON")             { expect_failed("this is not json at all", "JSON parse failed") }
      it("fails a JSON array")                      { expect_failed("[1, 2]", "Expected a JSON object") }
      it("fails a missing request")                 { expect_failed(valid_result.except("request").to_json, "request must be an object") }
      it("fails a blank title")                     { expect_failed(with_request("title" => " ").to_json, "title is missing") }
      it("fails a blank description")               { expect_failed(with_request("description" => "").to_json, "description is missing") }
      it("fails a blank what_changed")              { expect_failed(valid_result.merge("what_changed" => "").to_json, "what_changed is missing") }
      it("fails a non-string question")             { expect_failed(valid_result.merge("missing_detail_question" => [ "Where?" ]).to_json, "string or null") }
      it("fails a swap term without one_line")      { expect_failed(with_term("one_line" => "").to_json, "Each swap term needs") }

      # Hard rules (each mirrored by an adversarial eval case in evals/cases/unityoffers_request_v1.yml).
      it "fails a title over 80 characters" do
        expect_failed(with_request("title" => "a" * 81).to_json, "The request title was 81 characters; the limit is 80")
      end

      it "fails a category that is not in the member's list" do
        expect_failed(with_request("category" => "Pets").to_json, "\"Pets\" is not one of your board's categories")
      end

      it "fails one swap term" do
        expect_failed(valid_result.merge("swap_terms" => valid_result["swap_terms"].first(1)).to_json, "Expected 2 or 3 swap_terms, got 1")
      end

      it "fails four swap terms" do
        expect_failed(valid_result.merge("swap_terms" => valid_result["swap_terms"] * 2).to_json, "Expected 2 or 3 swap_terms, got 4")
      end

      it "fails a currency amount" do
        expect_failed(with_term("you_give" => "$20 for petrol").to_json, "a money amount or price")
      end

      it "fails a term called fair or best" do
        expect_failed(with_term("one_line" => "The fairest option: you drive, I mend.").to_json, "the word \"fair\" or \"best\"")
        expect_failed(valid_result.merge("what_changed" => "I picked the best swap for you.").to_json, "the word \"fair\" or \"best\"")
      end

      it "fails an email address, even one the member typed" do
        need.update!(rough_text: "Need a lift to the recycling centre. Email ro.marsh@example.org.")
        expect_failed(with_request("description" => "I could use a lift. Email ro.marsh@example.org.").to_json, "an email address")
      end

      it "fails a phone number, even one the member typed" do
        need.update!(rough_text: "Need a lift to the recycling centre. Call me on 555-0142.")
        expect_failed(with_request("description" => "I could use a lift. Call me on 555-0142.").to_json, "a phone number")
      end

      it "shows the reason, Retry and the raw response, with no download" do
        gemini_returns(with_term("one_line" => "The best swap: $20 cash.").to_json)
        write_draft
        follow_redirect!
        expect(response.body).to include("could not be used", "which this board never shows", "Retry", "The best swap: $20 cash.")
        expect(response.body).not_to include("Download .md")
      end
    end

    context "when GeminiService raises" do
      before { sign_in_as(user) }

      {
        GeminiService::BudgetExceededError => "daily AI request limit",
        GeminiService::GatekeeperError     => "couldn't be processed",
        GeminiService::OutputGuardError    => "didn't pass our safety checks",
        GeminiService::TimeoutError        => "took too long",
        GeminiService::GeminiError         => "An unexpected error occurred"
      }.each do |error_class, message|
        it "renders the #{error_class.name.demodulize} message with 422 and creates no draft" do
          gemini_raises(error_class)
          expect { write_draft }.not_to change(RequestDraft, :count)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include(message)
        end
      end
    end

    # open-base's ApplicationController answers RecordNotFound with a redirect to root and an alert.
    context "when signed in as a different user" do
      it "does not find the need, calls no AI, and creates no draft" do
        sign_in_as(other)
        expect(GeminiService).not_to receive(:generate)
        expect { write_draft }.not_to change(RequestDraft, :count)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("That record could not be found.")
      end
    end

    context "rate limit" do
      it "refuses the 11th draft within a minute" do
        sign_in_as(user)
        gemini_returns(valid_result.to_json)
        10.times { write_draft }
        expect(response).to have_http_status(:redirect)
        write_draft
        expect(response).to have_http_status(:too_many_requests)
        expect(RequestDraft.count).to eq(10)
      end
    end
  end

  describe "GET /needs/:need_id/drafts (a refresh after an error)" do
    it "redirects to the need" do
      sign_in_as(user)
      get need_request_drafts_path(need)
      expect(response).to redirect_to(need_path(need))
    end
  end

  describe "GET /needs/:need_id/drafts/:id" do
    context "for a completed draft" do
      let(:draft) { create(:request_draft, :completed, need: need, generated_at: 1.minute.from_now) }

      it "shows the request, the question, what changed, the swap ideas, the actions and the disclaimer" do
        sign_in_as(user)
        get need_request_draft_path(need, draft)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(
          "Request", draft.category, draft.title, draft.description, "One detail to add", draft.missing_detail_question,
          "What changed from your words", draft.what_changed, "Swap ideas", "You give", "They give",
          "Download .md", "Show raw response", "AI-generated."
        )
        expect(response.body).to include(ERB::Util.html_escape(draft.swap_terms.first["one_line"]))
        expect(response.body).not_to include("Your words have changed")
      end
    end

    context "for a failed draft" do
      it "shows the reason, Retry and the raw response, with no download" do
        draft = create(:request_draft, :failed, need: need)
        sign_in_as(user)
        get need_request_draft_path(need, draft)
        expect(response.body).to include("could not be used", draft.failure_reason, "Retry", "malformed response")
        expect(response.body).not_to include("Download .md")
      end
    end

    it "warns when the need changed after the draft" do
      draft = create(:request_draft, :completed, need: need, generated_at: 1.hour.ago)
      need.update!(time_window: "Next Sunday")
      sign_in_as(user)
      get need_request_draft_path(need, draft)
      expect(response.body).to include("Your words have changed since this draft")
    end

    it "does not show another user's draft" do
      draft = create(:request_draft, :completed, need: need)
      sign_in_as(other)
      get need_request_draft_path(need, draft)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That record could not be found.")
    end

    it "does not show a draft under a different need of the same user" do
      draft = create(:request_draft, :completed, need: need)
      sign_in_as(user)
      get need_request_draft_path(create(:need, user: user), draft)
      expect(response).to redirect_to(root_path)
    end
  end
end
