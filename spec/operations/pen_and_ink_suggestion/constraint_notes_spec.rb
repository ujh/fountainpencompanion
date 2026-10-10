require "rails_helper"

RSpec.describe PenAndInkSuggestion::ConstraintNotes do
  def constraints(hash)
    PenAndInkSuggestion::Constraints.from_h(hash)
  end

  describe ".excluded" do
    it "names every kind of pen exclusion" do
      pen_constraints =
        constraints(
          pen: {
            exclude_mentions: %w[Parker Sheaffer],
            comment_exclude: %w[grail],
            nib_grades_exclude: %w[EF F],
            nib_characters_exclude: %w[stub italic]
          }
        )

      expect(described_class.excluded(:pen, pen_constraints.exclusions(:pen), pen_constraints)).to(
        eq(
          "None of your uninked pens is left after excluding \"Parker\" and \"Sheaffer\", " \
            "pens whose comment mentions \"grail\", EF or F nibs and stub or italic nibs. " \
            "Change your request and try again."
        )
      )
    end

    it "names every kind of ink exclusion" do
      ink_constraints =
        constraints(
          ink: {
            tags_exclude: %w[office],
            kinds_exclude: %w[sample cartridge],
            shimmer: "exclude",
            scented: "exclude"
          }
        )

      expect(described_class.excluded(:ink, ink_constraints.exclusions(:ink), ink_constraints)).to(
        eq(
          "None of your inks is left after excluding inks tagged \"office\", ink samples or " \
            "cartridges, shimmer inks and scented inks. Change your request and try again."
        )
      )
    end
  end

  describe ".relaxations" do
    it "words the grades and characters with the right article" do
      notes =
        described_class.relaxations(
          [
            { "field" => "pen.nib_grades_include", "step" => "dropped", "from" => %w[EF F] },
            { "field" => "pen.nib_characters_include", "step" => "dropped", "from" => %w[italic] },
            { "field" => "pen.nib_characters_include", "step" => "dropped", "from" => %w[fude] }
          ],
          PenAndInkSuggestion::Constraints.empty
        )

      expect(notes).to eq(
        [
          "None of your uninked pens has an EF or F nib, so I chose from all nib sizes.",
          "None of your uninked pens has an italic nib, so I left the nib type open.",
          "None of your uninked pens has a fude nib, so I left the nib type open."
        ]
      )
    end

    it "tells missing cartridges apart from cartridges no pen takes" do
      notes =
        described_class.relaxations(
          [
            { "field" => "ink.kinds_include", "step" => "dropped", "from" => %w[cartridge] },
            {
              "field" => "ink.kinds_include",
              "step" => "dropped",
              "from" => %w[cartridge],
              "reason" => "no_fitting_pen"
            }
          ],
          PenAndInkSuggestion::Constraints.empty
        )

      expect(notes).to eq(
        [
          "You have no cartridges, so I picked from all your inks.",
          "None of your uninked pens takes cartridges, so I picked from all your inks."
        ]
      )
    end

    it "words pen usage both ways" do
      notes =
        described_class.relaxations(
          [
            { "field" => "pen.usage", "step" => "dropped", "from" => "never_used" },
            { "field" => "pen.usage", "step" => "dropped", "from" => "used_before" }
          ],
          PenAndInkSuggestion::Constraints.empty
        )

      expect(notes).to eq(
        [
          "All your uninked pens have been used before, so I included those.",
          "None of your uninked pens has been used before, so I included new ones."
        ]
      )
    end

    it "notes kept pins once per side" do
      notes =
        described_class.relaxations(
          [
            { "field" => "ink.colour_include", "step" => "pinned", "from" => ["red"] },
            { "field" => "ink.kinds_include", "step" => "pinned", "from" => ["sample"] }
          ],
          PenAndInkSuggestion::Constraints.empty
        )

      expect(notes).to eq(
        ["The inks you named don't meet your other ink requirements, so I kept them anyway."]
      )
    end
  end
end
