FactoryBot.define do
  factory :need do
    association :user
    rough_text  { "Sorry to ask, but my car is off the road and I need to get some boxes to the recycling centre." }
    could_offer { "I can hem or mend clothes." }
    categories  { Need::DEFAULT_CATEGORIES }
    time_window { "Any Saturday this month" }
    hours       { 2 }
  end
end
