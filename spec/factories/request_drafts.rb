FactoryBot.define do
  factory :request_draft do
    association :need
    status       { "pending" }
    generated_at { nil }
    gemini_raw   { nil }

    trait :completed do
      status                  { "completed" }
      generated_at            { Time.current }
      gemini_raw              { "{}" }
      title                   { "Lift to the recycling centre" }
      description             { "I could use a lift to the recycling centre with a pile of flattened boxes. Any Saturday this month works." }
      category                { "Rides" }
      what_changed            { "I dropped the apology and kept the boxes and the Saturday." }
      missing_detail_question { "Which recycling centre is it?" }
      swap_terms do
        [
          { "you_give" => "Hemming two items", "they_give" => "A Saturday lift",
            "one_line" => "You drive me to the recycling centre one Saturday; I hem two things for you." },
          { "you_give" => "Nothing this time", "they_give" => "The lift",
            "one_line" => "You give me a lift one Saturday, and nothing is expected back." }
        ]
      end
    end

    trait :failed do
      status         { "failed" }
      generated_at   { Time.current }
      gemini_raw     { "malformed response" }
      failure_reason { "JSON parse failed: unexpected token" }
    end
  end
end
