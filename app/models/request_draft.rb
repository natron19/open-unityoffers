class RequestDraft < ApplicationRecord
  belongs_to :need
  has_one :user, through: :need

  STATUSES        = %w[pending completed failed].freeze
  TITLE_MAX_CHARS = 80
  SWAP_TERM_COUNT = (2..3)

  validates :status, inclusion: { in: STATUSES }

  def completed? = status == "completed"
  def failed?    = status == "failed"

  # The need was edited after this draft was written.
  def stale?
    generated_at.present? && need.updated_at > generated_at
  end

  def to_markdown
    lines = []
    lines << "# Request: #{title}"
    lines << ""
    lines << "_Drafted #{generated_at&.strftime('%Y-%m-%d') || 'at an unknown time'} by #{ENV.fetch('APP_NAME', 'UnityOffers Demo')}. " \
             "AI-generated: a draft for you to edit before you post it. The swap ideas are options; " \
             "you and the other person decide._"
    lines << ""
    lines << "**Category:** #{category}"
    lines << ""
    lines << description.to_s
    lines << ""
    if missing_detail_question.present?
      lines << "_One detail to add:_ #{missing_detail_question}"
      lines << ""
    end
    lines << "## What changed from your words"
    lines << ""
    lines << what_changed.to_s
    lines << ""
    lines << "## Swap ideas"
    lines << ""
    swap_terms.each_with_index do |term, i|
      lines << "#{i + 1}. #{term['one_line']}"
      lines << "   - You give: #{term['you_give']}"
      lines << "   - They give: #{term['they_give']}"
    end
    lines << ""
    lines << "## Your words"
    lines << ""
    lines << "> #{need.rough_text.to_s.squish}"
    lines << ""
    lines << "_Could offer back:_ #{need.could_offer.presence || 'Nothing listed'}"
    lines << "_When:_ #{need.time_window.presence || 'Not stated'}"
    lines << "_Time it might take:_ #{need.hours_label}"
    lines.join("\n") + "\n"
  end

  def markdown_filename
    slug = title.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "").presence || "need"
    "#{slug}-request.md"
  end
end
