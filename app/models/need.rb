class Need < ApplicationRecord
  belongs_to :user
  has_many :request_drafts, dependent: :destroy
  has_one :latest_request_draft,
          -> { order(generated_at: :desc, created_at: :desc) },
          class_name: "RequestDraft"

  # The categories a new community board starts with (production's setup wizard offers these words).
  # The member can edit them: the AI must pick the request's category from this list.
  DEFAULT_CATEGORIES = "Tools, Rides, Meals, Repairs, Garden, Hours, Expertise, Produce, Space, Equipment".freeze
  CATEGORY_COUNT     = (2..12)
  CATEGORY_MAX_CHARS = 40
  HOURS_RANGE        = (1..40)

  before_validation :normalize_categories

  validates :rough_text,  presence: true, length: { in: 10..600 } # production caps rough_text at 600
  validates :could_offer, length: { maximum: 300 }
  validates :categories,  presence: true
  validates :time_window, length: { maximum: 120 }
  validates :hours,       numericality: { only_integer: true, in: HOURS_RANGE }, allow_nil: true
  validate  :category_list_is_usable

  # The board's categories as a clean list: split on commas or new lines, trimmed, de-duplicated.
  def category_list
    categories.to_s.split(/[,\n]/).map(&:strip).reject(&:blank?).uniq(&:downcase)
  end

  # The list entry a model answer names, matched without regard to case or spacing; nil when it is not in the list.
  def category_named(name)
    wanted = name.to_s.squish.downcase
    category_list.find { |c| c.squish.downcase == wanted }
  end

  # The member's words, shortened for a card or a page heading.
  def summary
    rough_text.to_s.squish.truncate(90)
  end

  def hours_label
    hours ? "About #{hours} #{'hour'.pluralize(hours)}" : "Not stated"
  end

  # Variables for the unityoffers_request_v1 template. Nothing about the member (name, email) is sent.
  def ai_variables
    {
      rough_text:     rough_text,
      could_offer:    could_offer.presence || "Nothing listed",
      category_names: category_list.join(", "),
      time_window:    time_window.presence || "Not stated",
      hours:          hours ? "about #{hours} #{'hour'.pluralize(hours)}" : "Not stated"
    }
  end

  private

  def normalize_categories
    self.categories = category_list.join(", ") if categories.present?
  end

  def category_list_is_usable
    return if categories.blank?

    unless CATEGORY_COUNT.cover?(category_list.size)
      errors.add(:categories, "must list #{CATEGORY_COUNT.min} to #{CATEGORY_COUNT.max} categories, separated by commas")
    end
    if category_list.any? { |c| c.length > CATEGORY_MAX_CHARS }
      errors.add(:categories, "can each be at most #{CATEGORY_MAX_CHARS} characters")
    end
  end
end
