require "rails_helper"

RSpec.describe BoardRulesCheck do
  describe ".violations" do
    it "passes ordinary neighbourly text" do
      text = "You give me a lift one Saturday at 9.30-11.30; I hem two things for you. Nothing is expected back. " \
             "It should take about 2 hours on 2026-10-17, during the 2025-2026 season, for 3 boxes."
      expect(described_class.violations(text)).to eq([])
      expect(described_class.clean?(text)).to be(true)
    end

    {
      "$25"                 => "I'll give you $25 for the lift.",
      "£ 10"                => "Worth about £ 10 of petrol.",
      "20€"                 => "Around 20€ is plenty.",
      "a currency code"     => "Roughly 15 USD.",
      "an amount in words"  => "I can give you 20 dollars.",
      "bucks"               => "A few bucks for petrol.",
      "a price word"        => "No price, just a swap.",
      "cash"                => "Cash or a cake, your choice.",
      "payment"             => "No payment needed."
    }.each do |label, text|
      it "flags money: #{label}" do
        expect(described_class.violations(text)).to include(:money)
      end
    end

    it "flags \"fair\" and \"best\" as whole words in any case, and not inside other words" do
      expect(described_class.violations("This is a fair swap.")).to eq([ :value ])
      expect(described_class.violations("The BEST option is the first.")).to eq([ :value ])
      expect(described_class.violations("Fairer for both of you.")).to eq([ :value ])
      expect(described_class.violations("Jam for the county fair.")).to eq([ :value ])
      expect(described_class.violations("An affair of the heart, unfairly bestowed.")).to eq([])
    end

    it "flags an email address" do
      expect(described_class.violations("Email ro.marsh@example.org to reply.")).to eq([ :email ])
    end

    {
      "a US number"            => "Call 555-014-2233.",
      "a local number"         => "Call me on 555-0142.",
      "a UK mobile"            => "Text 07700 900123.",
      "an international number" => "Ring +44 20 7946 0958."
    }.each do |label, text|
      it "flags #{label}" do
        expect(described_class.violations(text)).to eq([ :phone ])
      end
    end
  end

  describe ".failure_reason" do
    it "is nil for clean text" do
      expect(described_class.failure_reason("You lend me the ladder; I mend your coat.")).to be_nil
    end

    it "names every rule the text breaks" do
      reason = described_class.failure_reason("The best deal is $20. Call 555-0142 or email a.b@example.org.")
      expect(reason).to eq(
        "The response included a money amount or price, the word \"fair\" or \"best\", an email address, " \
        "and a phone number, which this board never shows"
      )
    end
  end
end
