class RequestDraftsController < ApplicationController
  TEMPLATE = "unityoffers_request_v1".freeze

  before_action :set_need

  rate_limit to: 10, within: 1.minute, only: :create, by: -> { current_user.id }

  # A refresh after an error page lands here (GET on the create path); send it back to the need.
  def index
    redirect_to need_path(@need)
  end

  def show
    @request_draft = @need.request_drafts.find(params[:id])
  end

  def create
    raw = GeminiService.generate(template: TEMPLATE, variables: @need.ai_variables)

    @request_draft = @need.request_drafts.create!(
      status:       "pending",
      gemini_raw:   raw,
      generated_at: Time.current
    )

    result = parse_draft!(raw)
    @request_draft.update!(result.merge(status: "completed"))
    redirect_to need_request_draft_path(@need, @request_draft)

  rescue ParseError => e
    @request_draft.update!(status: "failed", failure_reason: e.message.truncate(250), gemini_raw: e.raw)
    redirect_to need_request_draft_path(@need, @request_draft)

  rescue GeminiService::BudgetExceededError
    render "shared/ai_error_page", locals: { error_type: :budget_exceeded }, status: :unprocessable_entity

  rescue GeminiService::GatekeeperError
    render "shared/ai_error_page", locals: { error_type: :gatekeeper_blocked }, status: :unprocessable_entity

  rescue GeminiService::OutputGuardError
    render "shared/ai_error_page", locals: { error_type: :output_blocked }, status: :unprocessable_entity

  rescue GeminiService::TimeoutError
    render "shared/ai_error_page", locals: { error_type: :timeout }, status: :unprocessable_entity

  rescue GeminiService::GeminiError
    render "shared/ai_error_page", locals: { error_type: :error }, status: :unprocessable_entity
  end

  private

  def set_need
    @need = current_user.needs.find(params[:need_id])
  end

  ParseError = Class.new(StandardError) do
    attr_reader :raw
    def initialize(msg, raw:)
      super(msg)
      @raw = raw
    end
  end

  # Validates the unityoffers_request_v1 JSON and returns the RequestDraft attributes.
  # Hard rules enforced here, not trusted to the model: a title of at most 80 characters, a category copied from the
  # member's list, two or three swap terms, and no money, no "fair" or "best", and no contact details (BoardRulesCheck).
  def parse_draft!(raw)
    fail_parse = ->(msg) { raise ParseError.new(msg, raw: raw) }

    stripped = raw.to_s.strip.gsub(/\A```(?:json)?\s*|\s*```\z/, "").strip
    parsed   = JSON.parse(stripped)
    fail_parse.("Expected a JSON object") unless parsed.is_a?(Hash)

    request = parsed["request"]
    fail_parse.("request must be an object with a title, a description and a category") unless request.is_a?(Hash)

    title       = present_string(request["title"])
    description = present_string(request["description"])
    fail_parse.("The request title is missing") unless title
    fail_parse.("The request description is missing") unless description
    if title.length > RequestDraft::TITLE_MAX_CHARS
      fail_parse.("The request title was #{title.length} characters; the limit is #{RequestDraft::TITLE_MAX_CHARS}")
    end

    category = @need.category_named(request["category"])
    unless category
      fail_parse.("The category \"#{request['category'].to_s.truncate(40)}\" is not one of your board's categories")
    end

    what_changed = present_string(parsed["what_changed"])
    fail_parse.("what_changed is missing") unless what_changed

    question = parsed["missing_detail_question"]
    fail_parse.("missing_detail_question must be a string or null") unless question.nil? || question.is_a?(String)
    question = question.to_s.strip.presence

    terms = parsed["swap_terms"]
    unless terms.is_a?(Array) && RequestDraft::SWAP_TERM_COUNT.cover?(terms.size)
      fail_parse.("Expected 2 or 3 swap_terms, got #{Array(terms).size}")
    end
    terms = terms.map do |term|
      values = %w[you_give they_give one_line].index_with { |key| present_string(term.is_a?(Hash) ? term[key] : nil) }
      fail_parse.("Each swap term needs you_give, they_give and one_line") if values.values.any?(&:nil?)
      values
    end

    # The category is left out: it is the member's own word, already matched against their list.
    output_text = [ title, description, what_changed, question, *terms.flat_map(&:values) ].compact.join("\n")
    if (reason = BoardRulesCheck.failure_reason(output_text))
      fail_parse.(reason)
    end

    {
      title:                   title,
      description:             description,
      category:                category,
      what_changed:            what_changed,
      missing_detail_question: question,
      swap_terms:              terms
    }
  rescue JSON::ParserError => e
    raise ParseError.new("JSON parse failed: #{e.message.truncate(120)}", raw: raw)
  end

  # A stripped, non-blank string; nil for anything else.
  def present_string(value)
    value.is_a?(String) ? value.strip.presence : nil
  end
end
