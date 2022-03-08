# modelspec.jl

import Base.isless

include("udepToken.jl")

struct VocabSection   # used by ModelSpec's sDictVec
    key::String
    dict::Dict{String, UInt16}
end

struct FormLemmaPair
    form0::UInt8  # form section
    lemma0::UInt8 # lemma section
    form::UInt16  # form ID
    lemma::UInt16  # lemma ID
end

function isless(x1::FormLemmaPair, x2::FormLemmaPair) 
    x1.form0 < x2.form0 || 
    (x1.form0 == x2.form0 && 
        (x1.form < x2.form ||
        (x1.form == x2.form && 
            (x1.lemma0 < x2.lemma0 ||
            (x1.lemma0 == x2.lemma0 && x1.lemma < x2.lemma)))))
end

#  Featspec holds data from "featspec.csv"; 
#  processed by functions in "binarizeDepcc.jl"; 
#  depended on by "featdefs.jl" 
struct Featspec
    name::Symbol        # a function which extracts a feature's value from its input
    relation::Bool        # whether a function is a relation or not
    valSource::Symbol     # source for determining range of potential feature values
    filter::Int           # function which filters set of potential values
    transform::Symbol     # function used to map categorial values to model values, and back
    granularity::Symbol   # eg., token, clause, sentence, doc, etc.
    model::Bool           # whether feature should be included in model, or just used for setup purposes (eg CDform)
end

function Featspec(lineStr::Vector{SubString{String}})#, relationStr::SubString{String}, valSourceStr::SubString{String}, filterStr::SubString{String}, transformStr::SubString{String}, granularityStr::SubString{String}, modelStr::SubString{String}) 
    Featspec(Symbol(lineStr[1]), 
        parse(Bool, lineStr[2]), 
        Symbol(     lineStr[3]), 
        parse(Int,  lineStr[4]),
        Symbol(     lineStr[5]),
        Symbol(     lineStr[6]),
        parse(Bool, lineStr[7]))
end

struct ModelSpec
    delimChar::Char            # typically '\t' (tab) for natural language data
    beginDocTok::UdepTokenCore # symbol used to mark the start of a new doc and sentence
    beginSenTok::UdepTokenCore # symbol used to mark the start of a new sentence
    awsRegion::String   # region of s3 bucket containing input data from wiktionary and single depcc chunk used for setting up tiers
    s3bucket::String    # name offe bucket containing input data used to setup binarization
    dataPrefix::String  # location for reading and writing of data, "~/data" by default
    tierSource::String  # name of single depcc chunk used to setup feature combo tiers
    vocabSource::String # name of vocab source file, eg. derived from wikitionary
    tierFile::String    # name of output file that stores list of tiers
    vocabFile::String   # name of output file that stores global form+lemma vocab entries
    specFile::String    # name of output file that stores bindings for this ModelSpec
    udepFileList::String # list CoNLL-formatted files
    numTiers::UInt8     # number of feature combo sets organized by frequency, with fewer bytes associated with lower tiers
    tierThreshold::UInt # frequency level used as threshold between tiers
    tierIndices::Vector{UInt8}            # vector with numTiers entries ranging from 2-256 indicating the starting indices of each tier
    tierDict::Dict{UdepTokenCore, UInt8}  # maps feature combo to tier number for high frequency feature combos
    tierList::Vector{UdepTokenCore}       # ordinal list of tiered feature combos
    vocabDictVec::Vector{VocabSection}    # map token strings of global vocab to integers
    vocabList::Vector{String}             # ordinal list of global vocab
    lemmaList::Vector{FormLemmaPair}      # forms + lemmas that are not identical
    vals::Dict{Symbol, Any}               # values associated with ModelSpec
    #domainVocabList::Vector{String}       # domain-specific vocab
    #domainLemmaList::Vector{FormLemmaPair} # domain-specific vocab with non-identical lemmas
    catStrTransforms::Dict{Symbol, Pair{Dict{String, UInt8}, Vector{String}}} # Used to transform categorial values to IDs and back again
    featspecs::Vector{Featspec}             # Name, transform, class, granulary, etc of features
    featspecDict::Dict{Symbol, Featspec}
end
