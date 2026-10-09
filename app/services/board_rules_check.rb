# Code-side guard on AI output (not trusted to the model) for three of UnityOffers' board rules:
#
#   - No money. Money never moves through the board, so a draft never carries a currency amount ("$20", "15 euros",
#     "GBP") or a price word (price, cash, payment, dollars, bucks, ...).
#   - Never call an option "fair" or "best". The two people decide what is even; the AI only offers options. The words
#     are blocked in every sense, so "the county fair" is blocked too. The prompt tells the model to avoid them.
#   - No contact details. An email address or a phone number never appears in a draft, even one the member typed:
#     contact happens through the board. (AiOutputGuard only blocks contact details the model invented, and lets the
#     member's own back through, so this check is stricter.)
#
# Heuristic and deliberately blunt: it errs toward blocking, and a blocked draft shows the member the reason, the raw
# response, and a Retry button. Production UnityOffers keeps these rules in the template prompts; the demo also
# enforces them in code so they can be tested.
class BoardRulesCheck
  CURRENCY_AMOUNT = /
    [$£€¥₹]\s?\d                                              # $20, £ 5
    | \d[\d,.]*\s?[$£€¥₹]                                     # 20€
    | \b(?:USD|EUR|GBP|CAD|AUD|NZD|INR)\b                     # currency codes
    | \b\d[\d,.]*\s*(?:dollars?|bucks|euros?|quid|cents?)\b   # 20 dollars
  /ix

  PRICE_WORDS = /\b(?:prices?|priced|pricing|cash|payments?|dollars?|bucks|euros?|quid)\b/i
  VALUE_WORDS = /\b(?:fair|fairer|fairest|best)\b/i

  EMAIL = AiOutputGuard::PII_PATTERNS.fetch("email address")

  # A phone number: the US pattern AiOutputGuard uses, a local number ("555-0142"), or any run of digits and
  # separators carrying 9 to 15 digits ("07700 900123", "+44 20 7946 0958"). Dates ("2026-10-09"), times
  # ("9.30-11.30") and year ranges ("2025-2026") stay under these bars.
  US_PHONE      = AiOutputGuard::PII_PATTERNS.fetch("phone number")
  LOCAL_PHONE   = /(?<!\d)\d{3}[\s.-]\d{4}(?!\d)/
  DIGIT_RUN     = /\+?\(?\d[\d\s().-]{5,}\d/
  PHONE_DIGITS  = (9..15)

  RULES = {
    money:   "a money amount or price",
    value:   "the word \"fair\" or \"best\"",
    email:   "an email address",
    phone:   "a phone number"
  }.freeze

  # The rules the text breaks, as RULES keys (empty when the text is clean).
  def self.violations(text)
    text = text.to_s
    found = []
    found << :money if text.match?(CURRENCY_AMOUNT) || text.match?(PRICE_WORDS)
    found << :value if text.match?(VALUE_WORDS)
    found << :email if text.match?(EMAIL)
    found << :phone if phone?(text)
    found
  end

  # A plain sentence for the result page, or nil when the text is clean.
  def self.failure_reason(text)
    found = violations(text)
    return nil if found.empty?

    "The response included #{found.map { |key| RULES.fetch(key) }.to_sentence}, which this board never shows"
  end

  def self.clean?(text)
    violations(text).empty?
  end

  def self.phone?(text)
    return true if text.match?(US_PHONE) || text.match?(LOCAL_PHONE)

    text.scan(DIGIT_RUN).any? { |run| PHONE_DIGITS.cover?(run.count("0-9")) }
  end

  private_class_method :phone?
end
