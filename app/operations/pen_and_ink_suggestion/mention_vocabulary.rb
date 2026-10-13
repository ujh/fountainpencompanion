module PenAndInkSuggestion::MentionVocabulary
  COLOURS = <<~WORDS.split.freeze
    red orange yellow green teal blue purple violet pink brown grey gray black white gold golden
    silver turquoise burgundy navy cyan magenta maroon olive beige sepia aqua lavender lilac indigo
    crimson scarlet sage mint rust plum coral berry wine ochre khaki tan cream ivory charcoal slate
    amber copper bronze peach salmon lime mauve fuchsia cerulean cobalt colour colours color colors
    coloured colored hue hues shade shades tone tones light lighter dark darker bright brighter pale
    deep vivid pastel muted dusty saturated rot rote roten roter rotes gelb gelbe gelben grun grune
    grunen gruner blau blaue blauen blauer lila rosa braun braune braunen grau graue grauen schwarz
    schwarze schwarzen weiss weiß weisse turkis violett farbe farben hell helle dunkel dunkle rojo
    roja rojos amarillo amarilla verde verdes azul azules morado morada marron gris negro negra
    blanco blanca naranja claro oscuro
  WORDS

  NIBS = <<~WORDS.split.freeze
    ef f m b bb bbb mf fm xf xxf uef eef sf sm sef fine extrafine extra medium broad bold stub stubs
    italic nib nibs flex flexible fude oblique architect cursive grind needlepoint zoom music ci sig
    breit breite breiter breitere breiten feder fein feine mittel fina media ancha plumin plumilla
  WORDS

  INK_KINDS = <<~WORDS.split.freeze
    ink inks tinte tinten tinta tintas sample samples bottle bottles bottled cartridge cartridges
    converter converters swab swabs vial vials muestra muestras probe proben patrone patronen
  WORDS

  SEASONS = <<~WORDS.split.freeze
    spring summer autumn fall winter christmas xmas holiday holidays halloween easter valentine
    valentines season seasonal fruhling sommer herbst weihnachten primavera verano otono invierno
    navidad
  WORDS

  PROPERTIES = <<~WORDS.split.freeze
    shimmer shimmering shimmery sheen sheening sheeny shading shader shaders glitter sparkle
    sparkles sparkly scented scent waterproof permanent pigment pigmented iron gall wet wetter dry
    drier dryer
  WORDS

  PENS = <<~WORDS.split.freeze
    pen pens fountain fountainpen fueller fuller fullhalter pluma plumas
  WORDS

  STOP = (COLOURS + NIBS + INK_KINDS + SEASONS + PROPERTIES + PENS).to_set.freeze

  FILLER = <<~WORDS.split.to_set.freeze
    a an the my me i im id ive mine our we you your this that these those it its s for with to in
    into on onto of and or nor but at by from as is are be was were am do does did can could would
    should will shall please pls suggest suggestion suggestions recommend recommendation pick choose
    select give find use using used want wanna need like love try put fill filling something
    anything some any one ones what which how about maybe perhaps also too just only really very
    good great nice best next time today currently now again new newest old favourite favorite
    unused never haven inked inking pair pairing pairings combo combination match matching goes go
    up so if then than ich mein meine meinen meiner mit fur und oder der die das den dem ein eine
    einen einem bitte zu im mi mis con para y o el la los las un una por favor
  WORDS

  NEGATIONS = <<~WORDS.split.to_set.freeze
    not no non never without except excluding exclude avoid other besides instead unlike similar
    complement complements complementing resembling t nicht kein keine keinen keiner ohne ausser
    außer sin excepto ni
  WORDS

  module_function

  def stop?(word) = STOP.include?(word)

  def filler?(word) = FILLER.include?(word)

  def negation?(word) = NEGATIONS.include?(word)

  def evidence?(word) = !stop?(word) && !filler?(word)

  def pen_word?(word) = PENS.include?(word)

  def ink_word?(word) = INK_KINDS.include?(word)
end
