require "rails_helper"

describe NibProfile do
  describe ".parse" do
    describe "grades and width classes" do
      [
        ["F", "Lamy", { grade: "F", width: 3, japanese_sizing: false, confidence: :high }],
        ["M", "Pelikan", { grade: "M", width: 4, japanese_sizing: false }],
        ["EF", "TWSBI", { grade: "EF", width: 2 }],
        ["B", "Pelikan", { grade: "B", width: 5 }],
        ["BB", "Kaweco", { grade: "BB", width: 6 }],
        ["BBB", "Pelikan", { grade: "BBB", width: 7 }],
        ["3B", "Montblanc", { grade: "BBB", width: 7 }],
        ["EEF", "Scribo", { grade: "EEF", width: 1 }],
        ["XXF", "Osprey", { grade: "EEF", width: 1 }],
        ["MF", "Diplomat", { grade: "MF", width: 4 }],
        ["FM", "Diplomat", { grade: "MF", width: 4 }],
        ["Fine", "Lamy", { grade: "F", width: 3 }],
        ["fine", "Kaweco", { grade: "F", width: 3 }],
        ["Medium", "Kaweco", { grade: "M", width: 4 }],
        ["Broad", "Kaweco", { grade: "B", width: 5 }],
        ["Bold", "Parker", { grade: "B", width: 5 }],
        ["Extra Fine", "TWSBI", { grade: "EF", width: 2 }],
        ["Extra-Fine", "Faber-Castell", { grade: "EF", width: 2 }],
        ["XF", "Lamy", { grade: "EF", width: 2 }],
        ["Double Broad", "Lamy", { grade: "BB", width: 6 }],
        ["Extra Broad", "Visconti", { grade: "BB", width: 6 }],
        ["EB", "Visconti", { grade: "BB", width: 6 }],
        ["Medium Fine", "Opus 88", { grade: "MF", width: 4 }],
        ["Fine-Medium", "Diplomat", { grade: "MF", width: 4 }],
        ["F/M", "Jinhao", { grade: "MF", width: 4 }],
        ["M/F", "Jinhao", { grade: "MF", width: 4 }],
        ["F-M Gold", "Montblanc", { grade: "MF", material: :gold }],
        ["EF/F", "Jinhao", { grade: "EF", width: 2 }],
        ["Mediana", "Inoxcrom", { grade: "M", width: 4 }],
        ["Fina", "Inoxcrom", { grade: "F", width: 3 }],
        ["Extra Fino", "Aurora", { grade: "EF", width: 2 }],
        ["Fein", "Pelikan", { grade: "F", width: 3 }],
        ["Mittel", "Pelikan", { grade: "M", width: 4 }],
        ["Breit", "Pelikan", { grade: "B", width: 5 }],
        ["<F>", "Lamy", { grade: "F", width: 3 }],
        ["M?", "Pelikan", { grade: "M", width: 4 }],
        ["-M-", "Pelikan", { grade: "M", width: 4 }],
        ["Jinhao Fine", "Jinhao", { grade: "F", width: 3 }],
        ["Jowo #6 Broad", "Benu", { grade: "B", width: 5 }],
        ["Coarse", "Opus 88", { grade: "C", width: 5 }],
        ["C", "Lamy", { grade: nil, width: nil, confidence: :none }],
        ["Mediium", "Pelikan", { kind: :fountain, grade: nil, width: nil, confidence: :none }]
      ].each do |nib, brand, expected|
        it "reads #{nib.inspect} on a #{brand} pen" do
          expect(described_class.parse(nib, brand:)).to have_attributes(expected)
        end
      end
    end

    describe "Japanese sizing" do
      [
        ["F", "Pilot", { grade: "F", width: 2, japanese_sizing: true }],
        ["F", "Namiki", { grade: "F", width: 2, japanese_sizing: true }],
        ["EF", "Platinum", { grade: "EF", width: 1, japanese_sizing: true }],
        ["UEF", "Platinum", { grade: "UEF", width: 1, japanese_sizing: true }],
        ["MF", "Sailor", { grade: "MF", width: 3, japanese_sizing: true }],
        ["M", "Sailor", { grade: "M", width: 3, japanese_sizing: true }],
        ["B", "Sailor", { grade: "B", width: 4, japanese_sizing: true }],
        ["BB", "Pilot", { grade: "BB", width: 5, japanese_sizing: true }],
        ["M", "Platinium", { grade: "M", width: 3, japanese_sizing: true }],
        ["M", "Pilot / Namiki", { grade: "M", width: 3, japanese_sizing: true }],
        ["F", "Sailor x Bungubox", { grade: "F", width: 2, japanese_sizing: true }],
        ["M", "Nakaya", { grade: "M", width: 3, japanese_sizing: true }],
        ["F", "Taccia", { grade: "F", width: 2, japanese_sizing: true }],
        ["EF", "Kakimori", { grade: "EF", width: 1, japanese_sizing: true }],
        ["C", "Pilot", { grade: "C", width: 5, japanese_sizing: true }],
        ["C", "Platinum", { grade: "C", width: 5, japanese_sizing: true }],
        ["Coarse", "Platinium", { grade: "C", width: 5 }],
        ["H-MF", "Sailor", { grade: "MF", width: 3, characters: [] }],
        ["H-EF", "Sailor", { grade: "EF", width: 1, characters: [] }],
        ["HM", "Sailor", { grade: "M", width: 3, characters: [] }],
        ["H-B", "Sailor", { grade: "B", width: 4, characters: [] }],
        ["FA", "Pilot", { grade: nil, width: 2, japanese_sizing: false }]
      ].each do |nib, brand, expected|
        it "reads #{nib.inspect} on a #{brand} pen" do
          expect(described_class.parse(nib, brand:)).to have_attributes(expected)
        end
      end

      it "sizes a Pilot Custom 74 M one class finer than a Pelikan M" do
        pilot = described_class.parse("M", brand: "Pilot", model: "Custom 74")
        pelikan = described_class.parse("M", brand: "Pelikan", model: "M400")

        expect(pilot).to have_attributes(grade: "M", width: 3)
        expect(pelikan).to have_attributes(grade: "M", width: 4)
      end
    end

    describe "brand codes" do
      [
        ["FA", "Pilot", { width: 2, width_min: 2, width_max: 5, characters: [:flex] }],
        ["Falcon", "Pilot", { width: 3, characters: [:flex], confidence: :medium }],
        ["SF", "Pilot", { grade: "F", width: 2, width_max: 3, characters: [:soft] }],
        ["SEF", "Pilot", { grade: "EF", width: 1, width_max: 2, characters: [:soft] }],
        ["SFM", "Pilot", { grade: "MF", width: 3, width_max: 4, characters: [:soft] }],
        ["SM", "Platinum", { grade: "M", width: 3, width_max: 4, characters: [:soft] }],
        ["SB", "Pilot", { grade: "B", width: 4, characters: [:soft] }],
        ["S", "Pilot", { grade: nil, width: 6, characters: [:signature] }],
        ["S", "TWSBI", { width: nil, characters: [], confidence: :none }],
        ["CM", "Pilot", { grade: nil, width: 4, characters: [:italic], confidence: :high }],
        ["PO", "Pilot", { width: 1, characters: [:posting] }],
        ["WA", "Pilot", { width: 4, characters: [:waverly] }],
        ["SU", "Pilot", { width: 4, characters: [:stub] }],
        ["MS", "Pilot", { width: 5, characters: [:music] }],
        ["3.8", "Pilot", { width: 7, characters: [:parallel] }],
        ["1.5", "Pilot", { width: 7, characters: [:parallel] }],
        ["6.0", "Pilot", { width: 7, characters: [:parallel] }],
        ["Parallel", "Pilot", { width: 7, characters: [:parallel] }],
        ["Zoom", "Sailor", { width: 5, width_min: 3, width_max: 6, characters: [:zoom] }],
        ["Z", "Sailor", { width: 5, characters: [:zoom] }],
        ["Z", "Lamy", { width: nil, characters: [] }],
        ["Music", "Sailor", { width: 5, width_min: 3, width_max: 6, characters: [:music] }],
        ["NMF", "Sailor", { grade: "MF", width: 3, width_min: 2, width_max: 5 }],
        ["NMF", "Sailor", { characters: [:naginata], japanese_sizing: true }],
        ["N-MF", "Sailor", { grade: "MF", width: 3, characters: [:naginata] }],
        ["Naginata Togi", "Sailor", { width: 4, width_min: 3, width_max: 6 }],
        ["Cross Point", "Sailor", { characters: [:naginata] }],
        ["King Eagle", "Sailor", { characters: [:naginata] }],
        ["Emperor", "Sailor", { characters: [:naginata] }],
        ["Kodachi", "Bungubox", { width: 4, characters: [:naginata] }],
        ["Long Knife", "Kaigelu", { characters: [:naginata] }],
        ["Fude de Mannen", "Sailor", { width: 5, width_min: 3, width_max: 7, characters: [:fude] }],
        ["02", "Platinum", { grade: "EF", width: 1, japanese_sizing: true }],
        ["03", "Platinum", { grade: "F", width: 2, japanese_sizing: true }],
        ["05", "Platinum", { grade: "M", width: 3, japanese_sizing: true }],
        [".03", "Platinum", { grade: "F", width: 2 }],
        ["0.03", "Platinum", { grade: "F", width: 2 }],
        ["0.5", "Platinum", { grade: "M", width: 3 }],
        ["F (03)", "Platinum", { grade: "F", width: 2 }],
        ["03 F", "Platinum", { grade: "F", width: 2 }],
        ["03", "Jinhao", { grade: "F", width: 3, japanese_sizing: false }],
        ["KF", "Pelikan", { grade: "F", width: 3, characters: [] }],
        ["IB", "Pelikan", { grade: "B", width: 5, characters: [:italic] }],
        ["OB", "Pelikan", { grade: "B", width: 5, characters: [:oblique] }],
        ["OM", "Pelikan", { grade: "M", width: 4, characters: [:oblique] }],
        ["O3B", "Pelikan", { grade: "BBB", width: 7, characters: [:oblique] }],
        ["OM", "Lamy", { grade: "M", width: 4, characters: [:oblique] }],
        ["OB 18K Gold", "Waterman", { grade: "B", characters: [:oblique], material: :gold }],
        ["Gold OF", "Pelikan", { grade: "F", width: 3, characters: [:oblique] }],
        ["of", "Pelikan", { grade: "F", characters: [:oblique] }],
        ["IM 14K Gold", "Pelikan", { grade: "M", characters: [:italic] }],
        ["Made of steel", "Lamy", { grade: nil, characters: [], material: :steel }],
        ["Medium, made of gold", "Conklin", { grade: "M", width: 4, characters: [] }],
        ["Sailor King of Pen M", "Edison", { grade: "M", characters: [] }],
        ["Secretary of De Flex", "Opus 88", { grade: nil, characters: [:flex] }],
        ["Of Course F", "Lamy", { grade: "F", characters: [] }],
        ["Feder im Stil M", "Pelikan", { grade: "M", characters: [] }],
        ["2668", "Esterbrook", { grade: "M", width: 4, characters: [] }],
        ["9550", "Esterbrook", { grade: "EF", width: 2, characters: [] }],
        ["2556", "Esterbrook", { grade: "F", width: 3 }],
        ["9128", "Esterbrook", { grade: "EF", width: 2, width_max: 5, characters: [:flex] }],
        ["9314", "Esterbrook", { grade: "M", characters: %i[stub oblique] }],
        ["9048", "Esterbrook", { grade: "F", characters: [:stub] }],
        ["2442", "Esterbrook", { grade: "M", characters: [:stub] }],
        ["2668", "", { grade: "M", width: 4 }],
        ["1551", "Esterbrook", { grade: nil, width: nil }],
        ["Journaler", "Esterbrook", { width: 4, width_min: 2, characters: [:stub] }],
        ["Scribe", "Esterbrook", { width: 3, width_max: 5, characters: [:architect] }],
        ["Needlepoint", "Esterbrook", { width: 1, characters: [:needlepoint] }],
        ["Techo", "Esterbrook", { characters: [:naginata] }],
        ["Mini Stub", "Esterbrook", { width: 5, characters: [:stub] }],
        ["LH", "Lamy", { width: 4, characters: [:left_handed] }],
        ["A", "Lamy", { width: 4, characters: [:beginner] }],
        ["A", "Pelikan", { width: 4, characters: [:beginner] }],
        ["A", "Herlitz", { width: nil, characters: [] }],
        ["Kanji", "Lamy", { width: 4, characters: [:italic] }],
        ["Cursive", "Lamy", { width: 4, characters: [:italic] }],
        ["Cursive", "Schon DSGN", { width: 5, characters: [:italic] }],
        ["1.1", "Lamy", { width: 6, width_min: 3, characters: [:stub] }],
        ["1.5", "Lamy", { width: 7, characters: [:stub] }],
        ["1.9", "Lamy", { width: 7, characters: [:stub] }],
        ["SIG", "Franklin-Christoph", { width: 5, characters: [:italic] }],
        ["S.I.G.", "Franklin-Christoph", { width: 5, characters: [:italic] }],
        ["M SIG", "Franklin-Christoph", { grade: "M", width: 4, characters: [:italic] }],
        ["Monoc", "Schon DSGN", { material: :titanium, width: nil, confidence: :material_only }],
        ["Hooded", "Parker", { width: nil, confidence: :none }],
        ["EF Hooded", "Parker", { grade: "EF", width: 2 }]
      ].each do |nib, brand, expected|
        it "reads #{nib.inspect} on a #{brand.presence || "unbranded"} pen" do
          expect(described_class.parse(nib, brand:)).to have_attributes(expected)
        end
      end
    end

    describe "grinds and characters" do
      [
        ["1.1 Stub", { grade: nil, width: 6, width_min: 3, width_max: 6, characters: [:stub] }],
        ["1,1", { width: 6, characters: [:stub] }],
        ["Stub 1.1mm", { width: 6, characters: [:stub] }],
        ["1.1 Stub Steel", { width: 6, characters: [:stub], material: :steel }],
        ["Stub", { width: 6, width_min: 2, characters: [:stub], confidence: :medium }],
        ["B Stub", { grade: "B", width: 5, characters: [:stub] }],
        ["Medium Stub", { grade: "M", width: 4, width_min: 1, characters: [:stub] }],
        ["Italic", { width: 5, width_min: 2, characters: [:italic] }],
        ["1.1 Italic", { width: 6, characters: [:italic] }],
        ["Medium Italic", { grade: "M", width: 4, characters: [:italic] }],
        ["Cursive Italic", { width: 5, characters: [:italic] }],
        ["MCI", { grade: "M", characters: [:italic] }],
        ["FCI", { grade: "F", characters: [:italic] }],
        ["M CSI", { grade: "M", characters: [:italic] }],
        ["Calligraphy", { width: 5, characters: [:italic] }],
        ["Architect", { width: 4, width_min: 4, width_max: 6, characters: [:architect] }],
        ["M Architect Custom #5", { grade: "M", width: 4, characters: [:architect] }],
        ["Reverse", { width: nil, characters: [:reverse_grind], confidence: :character_only }],
        ["Oblique", { width: nil, characters: [:oblique], confidence: :character_only }],
        ["Oblique Medium", { grade: "M", width: 4, characters: [:oblique] }],
        ["Fude", { width: 5, width_min: 3, width_max: 7, characters: [:fude] }],
        ["Bent", { width: 5, characters: [:fude] }],
        ["Brush", { width: 5, characters: [:fude] }],
        ["Flex", { width: 3, width_min: 3, width_max: 6, characters: [:flex] }],
        ["Omniflex", { width: 3, characters: [:flex] }],
        ["Ultra Flex", { width: 3, characters: [:flex] }],
        ["EF Flex", { grade: "EF", width: 2, width_max: 5, characters: [:flex] }],
        ["Fine Flex", { grade: "F", width: 3, width_max: 6, characters: [:flex] }],
        ["Semi Flex", { width: nil, characters: [:soft], confidence: :character_only }],
        ["Semi-flex F", { grade: "F", width: 3, width_max: 4, characters: [:soft] }],
        ["Soft Fine", { grade: "F", width: 3, width_max: 4, characters: [:soft] }],
        ["Elastic Fine", { grade: "F", characters: [:soft] }],
        ["Soft Fine Medium", { grade: "MF", characters: [:soft] }],
        ["Needlepoint", { width: 1, characters: [:needlepoint] }],
        ["Posting", { width: 1, characters: [:posting] }],
        ["Waverly", { width: 4, characters: [:waverly] }],
        ["Signature", { width: 6, characters: [:signature] }],
        ["Long Blade", { width: 4, characters: [:naginata] }],
        ["Blade F", { grade: "F", width: 3, width_min: 2, width_max: 5, characters: [:naginata] }],
        ["Music 14k", { width: 5, characters: [:music], material: :gold }],
        ["Beginner", { width: 4, characters: [:beginner] }],
        ["Left-handed", { width: 4, characters: [:left_handed] }]
      ].each do |nib, expected|
        it "reads #{nib.inspect}" do
          expect(described_class.parse(nib)).to have_attributes(expected)
        end
      end
    end

    describe "line widths" do
      [
        ["0.5mm", "PenBBS", { grade: nil, width: 4, characters: [], confidence: :high }],
        ["0.3", "Wing Sung", { width: 2 }],
        [".6mm", "Nemosine", { width: 4 }],
        ["0.7 mm", "Jinhao", { width: 5, characters: [] }],
        ["0.2mm EF", "Hongdian", { grade: "EF", width: 1 }],
        ["EF (0,38 mm)", "Jinhao", { grade: "EF", width: 3, kind: :fountain }],
        ["1.1mm Stub", "TWSBI", { width: 6, characters: [:stub] }],
        ["6.0", "Lamy", { width: 7, characters: [:stub] }],
        ["#6", "Jowo", { width: nil, confidence: :none }],
        ["No.6 EF", "Jowo", { grade: "EF", width: 2 }],
        ["Bock No.8 F", "Benu", { grade: "F", width: 3, characters: [] }],
        ["M no.8", "Onoto", { grade: "M", width: 4 }],
        ["Nr.6 B", "Kaweco", { grade: "B", width: 5 }],
        ["No.6", "Jowo", { width: nil, confidence: :none }],
        ["O.6 Stub", "Monteverde", { width: 4, characters: [:stub], confidence: :high }],
        ["O.5mm", "Platinum", { grade: "M", width: 3 }],
        ["5", "Conway Stewart", { width: nil, confidence: :none }],
        ["Fine Steel 6/35", "Leonardo", { grade: "F", width: 3, material: :steel }]
      ].each do |nib, brand, expected|
        it "reads #{nib.inspect} on a #{brand} pen" do
          expect(described_class.parse(nib, brand:)).to have_attributes(expected)
        end
      end
    end

    describe "width precedence" do
      it "prefers an explicit mm over a code width" do
        expect(described_class.parse("Journaler 0.8mm", brand: "Esterbrook").width).to eq(5)
      end

      it "prefers an explicit mm over the grade" do
        expect(described_class.parse("EF (0.38mm)", brand: "Jinhao").width).to eq(3)
      end

      it "prefers a code width over the grade" do
        profile = described_class.parse("Calligraphy Medium", brand: "Pilot")

        expect(profile).to have_attributes(grade: "M", width: 4, japanese_sizing: false)
      end

      it "prefers the grade over a character default" do
        expect(described_class.parse("B Stub", brand: "TWSBI").width).to eq(5)
        expect(described_class.parse("Stub", brand: "TWSBI").width).to eq(6)
      end
    end

    describe "material" do
      [
        ["M 14k", { material: :gold, grade: "M" }],
        ["18K F", { material: :gold }],
        ["14kt M", { material: :gold }],
        ["Fine 14 ct", { material: :gold }],
        ["F 750", { material: :gold }],
        ["M 18K Rh.", { material: :gold }],
        ["Gold", { material: :gold, width: nil, confidence: :material_only }],
        ["Palladium M", { material: :gold }],
        ["F Steel", { material: :steel, grade: "F" }],
        ["Stainless Steel EF", { material: :steel }],
        ["Steal Medium", { material: :steel, grade: "M" }],
        ["M, SS", { material: :steel }],
        ["Plume acier M", { material: :steel, grade: "M" }],
        ["F Steel 18kgp", { material: :steel }],
        ["F gold plated", { material: :steel }],
        ["EF Steel Esterbrook Nib, Gold", { material: :steel, grade: "EF" }],
        ["Iridium Point Germany", { material: :steel, width: nil }],
        ["Titanium Fine", { material: :titanium, grade: "F" }],
        ["Steel", { material: :steel, width: nil, confidence: :material_only }],
        ["14k", { material: :gold, width: nil, confidence: :material_only }],
        ["Brass", { material: nil, width: nil, confidence: :none }]
      ].each do |nib, expected|
        it "reads #{nib.inspect}" do
          expect(described_class.parse(nib)).to have_attributes(expected)
        end
      end
    end

    describe "kind" do
      [
        ["Rollerball", nil, :rollerball],
        ["RB", nil, :rollerball],
        ["Roller Ball", nil, :rollerball],
        ["Ballpoint", nil, :non_inkable],
        ["BP PEN", nil, :non_inkable],
        ["Ballpoint/Rollerball", nil, :non_inkable],
        ["Pencil", nil, :non_inkable],
        ["Highlighter", nil, :non_inkable],
        ["Felt tip", nil, :non_inkable],
        ["Gel", nil, :non_inkable],
        ["0.38", "Uni-Ball", :non_inkable],
        ["0.5 mm", "Zebra", :non_inkable],
        ["0.38", "Jinhao", :fountain],
        ["Glass", nil, :dip],
        ["Dip nib", nil, :dip],
        ["Nikko", nil, :dip],
        ["Zebra G", nil, :dip],
        ["?", nil, :unknown],
        ["-", nil, :unknown],
        ["---", nil, :unknown],
        ["None", nil, :unknown],
        ["Unknown", nil, :unknown],
        ["N/A", nil, :unknown],
        ["idk", nil, :unknown],
        ["Various", nil, :unknown],
        ["Multiple", nil, :unknown],
        ["Interchangeable", nil, :unknown],
        ["None (interchangeable)", nil, :unknown],
        ["Double Ended", nil, :unknown],
        ["Standard", nil, :unknown],
        ["", nil, :unknown],
        [nil, nil, :unknown],
        ["Jowo #6", nil, :fountain],
        ["Bock", nil, :fountain],
        ["Warranted", nil, :fountain],
        ["Sankakusen", "Kyuseido", :fountain]
      ].each do |nib, brand, kind|
        it "reads #{nib.inspect}#{" on a #{brand} pen" if brand} as #{kind}" do
          expect(described_class.parse(nib, brand:).kind).to eq(kind)
        end
      end

      it "gives non-fountain pens no width or characters" do
        expect(described_class.parse("Rollerball")).to have_attributes(
          width: nil,
          characters: [],
          confidence: :none
        )
      end

      it "keeps parsing dip nibs" do
        expect(described_class.parse("Zebra G")).to have_attributes(width: 3, characters: [:flex])
      end

      it "gives junk values no width" do
        expect(described_class.parse("?")).to have_attributes(width: nil, confidence: :none)
      end

      it "leaves unit-only values without a width" do
        expect(described_class.parse("Jowo #6")).to have_attributes(
          kind: :fountain,
          width: nil,
          confidence: :none
        )
      end
    end

    describe "empty nib" do
      [
        ["Noodler's", "Ahab Flex", { width: 3, characters: [:flex], confidence: :medium }],
        ["Pilot", "Parallel 2.4 mm", { width: 7, characters: [:parallel], confidence: :high }],
        ["Pilot", "Parallel 3.8", { width: 7, characters: [:parallel] }],
        ["Nemosine", ".6mm Stub", { width: 4, characters: [:stub] }],
        ["Sailor", "Profit Fude de Mannen", { width: 5, characters: [:fude] }],
        ["Sailor", "1911 Zoom", { width: 5, characters: [:zoom] }],
        ["Noodler's", "Neponset Music Nib", { width: 5, characters: [:music] }],
        ["Lamy", "Safari (EF)", { grade: "EF", width: 2 }],
        ["Pilot", "Custom 74 (M)", { grade: "M", width: 3, japanese_sizing: true }]
      ].each do |brand, model, expected|
        it "falls back to #{model.inspect} on a #{brand} pen" do
          profile = described_class.parse("", brand:, model:)

          expect(profile).to have_attributes(kind: :fountain, source: :model, **expected)
        end
      end

      it "doesn't read loose words in the model name" do
        profile = described_class.parse("", brand: "Pilot", model: "Year of the Rabbit")

        expect(profile).to have_attributes(kind: :unknown, width: nil, characters: [])
      end

      it "doesn't read a semi-flex model as flex" do
        profile = described_class.parse("", brand: "Noodler's", model: "Semi-Flex")

        expect(profile).to have_attributes(kind: :unknown, characters: [])
      end

      it "is unknown when the model has no strong tokens" do
        profile = described_class.parse(nil, brand: "Pilot", model: "Custom 74")

        expect(profile).to have_attributes(kind: :unknown, width: nil, source: :nib)
      end

      it "ignores the model when a nib is entered" do
        profile = described_class.parse("F", brand: "Noodler's", model: "Ahab Flex")

        expect(profile).to have_attributes(grade: "F", characters: [], source: :nib)
      end
    end

    it "keeps the original text" do
      expect(described_class.parse(" 1,1 Stub ").raw).to eq(" 1,1 Stub ")
    end
  end

  describe ".width_class" do
    {
      0.17 => 1,
      0.27 => 1,
      0.28 => 2,
      0.37 => 2,
      0.38 => 3,
      0.49 => 3,
      0.5 => 4,
      0.69 => 4,
      0.7 => 5,
      0.94 => 5,
      0.95 => 6,
      1.24 => 6,
      1.25 => 7,
      6.0 => 7
    }.each do |mm, width|
      it "puts #{mm} mm into W#{width}" do
        expect(described_class.width_class(mm)).to eq(width)
      end
    end
  end

  describe "#fountain_pen?" do
    it "is true for fountain pens only" do
      expect(described_class.parse("F")).to be_fountain_pen
      expect(described_class.parse("Rollerball")).not_to be_fountain_pen
      expect(described_class.parse("Glass")).not_to be_fountain_pen
      expect(described_class.parse("?")).not_to be_fountain_pen
    end
  end

  describe "#broadish?" do
    it "is true from W4 up" do
      expect(described_class.parse("M", brand: "Pelikan")).to be_broadish
      expect(described_class.parse("B", brand: "Sailor")).to be_broadish
    end

    it "is false for a Pilot M" do
      expect(described_class.parse("M", brand: "Pilot")).not_to be_broadish
    end

    it "is true for a fine nib with a broad-ish character" do
      expect(described_class.parse("F Stub", brand: "TWSBI")).to be_broadish
      expect(described_class.parse("NMF", brand: "Sailor")).to be_broadish
    end

    it "is false for a flex F" do
      expect(described_class.parse("F Flex", brand: "Noodler's")).not_to be_broadish
    end

    it "is false without a width" do
      expect(described_class.parse("Steel")).not_to be_broadish
    end
  end

  describe "#broad?" do
    it "is true from W5 up" do
      expect(described_class.parse("B", brand: "Lamy")).to be_broad
      expect(described_class.parse("BB", brand: "Pilot")).to be_broad
      expect(described_class.parse("1.5 Stub", brand: "Lamy")).to be_broad
    end

    it "is false below W5" do
      expect(described_class.parse("M", brand: "Pelikan")).not_to be_broad
      expect(described_class.parse("B", brand: "Sailor")).not_to be_broad
      expect(described_class.parse("EF Flex", brand: "FPR")).not_to be_broad
    end

    it "is false without a width" do
      expect(described_class.parse("?")).not_to be_broad
    end
  end

  describe "#fine?" do
    it "is true for W1 to W3" do
      expect(described_class.parse("M", brand: "Pilot")).to be_fine
      expect(described_class.parse("EF", brand: "Lamy")).to be_fine
      expect(described_class.parse("F Flex", brand: "Noodler's")).to be_fine
    end

    it "is false for W4 and up" do
      expect(described_class.parse("M", brand: "Pelikan")).not_to be_fine
    end

    it "is false for a fine nib with a broad-ish character" do
      expect(described_class.parse("Blade F", brand: "Sailor")).not_to be_fine
      expect(described_class.parse("F Fude", brand: "Jinhao")).not_to be_fine
    end

    it "is false without a width" do
      expect(described_class.parse("Steel")).not_to be_fine
    end
  end

  describe "#matches_grade?" do
    it "matches the literal grade whatever the width class" do
      expect(described_class.parse("M", brand: "Pilot", model: "Custom 74")).to be_matches_grade(
        "M"
      )
      expect(described_class.parse("M", brand: "Pelikan")).to be_matches_grade("M")
    end

    it "ignores the case of the request" do
      expect(described_class.parse("MF", brand: "Sailor")).to be_matches_grade("mf")
    end

    it "doesn't match another grade of the same width class" do
      expect(described_class.parse("B", brand: "Sailor")).not_to be_matches_grade("M")
    end

    it "falls back to the Western width class without a parsed grade" do
      expect(described_class.parse("0.8 mm", brand: "Jinhao")).to be_matches_grade("B")
      expect(described_class.parse("1.5 Stub", brand: "Lamy")).not_to be_matches_grade("B")
    end

    it "doesn't match an unknown request or a pen without a width" do
      expect(described_class.parse("0.8 mm", brand: "Jinhao")).not_to be_matches_grade("Q")
      expect(described_class.parse("Steel")).not_to be_matches_grade("M")
    end
  end

  describe "#label" do
    [
      ["MF", "Sailor", nil, "MF → W3 (Japanese)"],
      ["1.1 Stub", "TWSBI", nil, "1.1 Stub → W6 stub (cross-strokes W3)"],
      ["Fude", "Jinhao", nil, "Fude → W5 fude (W3–W7)"],
      ["NMF", "Sailor", nil, "NMF → W3 (Japanese) naginata (W2–W5)"],
      ["F", "Lamy", nil, "F → W3"],
      ["Steel", "Lamy", nil, "Steel"],
      ["", "Pilot", "Custom 74", nil],
      ["", "Noodler's", "Ahab Flex", "flex (model name) → W3 flex (W3–W6)"]
    ].each do |nib, brand, model, label|
      it "labels #{nib.inspect} on a #{brand} pen as #{label.inspect}" do
        expect(described_class.parse(nib, brand:, model:).label).to eq(label)
      end
    end
  end
end
