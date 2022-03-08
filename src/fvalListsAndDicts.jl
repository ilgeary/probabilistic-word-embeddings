# fvalListsAndDicts.jl
# This file is now obsolete, but retained in case it might be helpful to review these lists of feature values.

const entityVals = [ # 7 vals
    "B-Location",
    "B-Organization",
    "B-Person",
    "I-Location",
    "I-Organization",
    "I-Person",
    "O"
]

const entityDict= Dict{String,UInt8}() 

for (i, v) in enumerate(entityVals)
    entityDict[v] = i
end

const capsVals = [ # 15 vals
    "none",
    "1st",
    "2nd",
    "3rd",
    "title",
    "camel",
    "all",
    "allButLast",
    "custom"
]
#=    "custom:1",
"custom:2",
"custom:3",
"custom:4",
"custom:5",
"custom:6",
"custom:7"
]=#

const capsDict= Dict{String,UInt8}() 

for (i, v) in enumerate(casetypeVals)
    casetypeDict[v] = i
end

const uposVals = [ # 45 vals plus two boundary markers
    "<beginDoc>",
    "<beginSen>",
    "#",
    "\$",
    "''",
    ",",
    "-LRB-",
    "-RRB-",
    ".",
    ":",
    "CC",
    "CD",
    "DT",
    "EX",
    "FW",
    "IN",
    "JJ",
    "JJR",
    "JJS",
    "LS",
    "MD",
    "NN",
    "NNP",
    "NNPS",
    "NNS",
    "PDT",
    "POS",
    "PRP",
    "PRP\$",
    "RB",
    "RBR",
    "RBS",
    "RP",
    "SYM",
    "TO",
    "UH",
    "VB",
    "VBD",
    "VBG",
    "VBN",
    "VBP",
    "VBZ",
    "WDT",
    "WP",
    "WP\$",
    "WRB",
    "``"
]

const uposDict = Dict{String,UInt8}() 

for (i, v) in enumerate(uposVals)
    uposDict[v] = i
end

# Maps a UposDict integer to a BasePos integer, in which nouns, verbs, adjectives and adverbs are lumped together in four groups
const basePosDict = Dict{UInt8,UInt8}() 

for (i, v) in enumerate(uposVals)
    startswith(v, "J") ? basePosDict[i] = uposDict["JJ"] :
    startswith(v, "N") || startswith(v, "CD") ? basePosDict[i] = uposDict["NN"] :
    startswith(v, "RB") ? basePosDict[i] = uposDict["RB"] :
    startswith(v, "V") ? basePosDict[i] = uposDict["VB"] :
    basePosDict[i] = i
end

const agreementNumberNone       = 0
const agreementNumberSingular   = 1
const agreementNumberPlural     = 2
const agreementNumberAmbiguous  = 3

const agreementNumberVals = [
    agreementNumberSingular,
    agreementNumberPlural,
    agreementNumberAmbiguous
]

# Agreement between verbs and nouns
const agreementNumberDict = Dict{UInt8,UInt8}() 

for (i, v) in enumerate(uposVals)
    v in ["CD"] ? agreementNumberDict[i]            = agreementNumberAmbiguous :  # ambiguous, eg: "one" vs. "two"
    v in ["NN", "NNP"] ? agreementNumberDict[i]     = agreementNumberSingular :   # singular
    v in ["NNPS", "NNS"] ? agreementNumberDict[i]   = agreementNumberPlural :     # plural
    v in ["VBP"] ? agreementNumberDict[i]           = agreementNumberPlural :     # plural
    v in ["VBZ"] ? agreementNumberDict[i]           = agreementNumberSingular :   # singular
    agreementNumberDict[i]                          = agreementNumberNone         # irrelevant
end

const singularCDstrs = ("one", "1", "1.0", "1.00")

const depRelVals = [ # 50 vals
    "ROOT",
    "abbrev",
    "acomp",
    "advcl",
    "advmod",
    "amod",
    "appos",
    "attr",
    "aux",
    "auxpass",
    "cc",
    "ccomp",
    "complm",
    "conj",
    "cop",
    "csubj",
    "csubjpass",
    "dep",
    "det",
    "dobj",
    "expl",
    "infmod",
    "iobj",
    "mark",
    "measure",
    "neg",
    "nn",
    "nsubj",
    "nsubjpass",
    "null",
    "num",
    "number",
    "parataxis",
    "partmod",
    "pcomp",
    "pobj",
    "poss",
    "possessive",
    "preconj",
    "pred",
    "predet",
    "prep",
    "prt",
    "punct",
    "purpcl",
    "quantmod",
    "rcmod",
    "rel",
    "tmod",
    "xcomp"
]

const depRelDict = Dict{String,UInt8}() 
for (i, v) in enumerate(depRelVals)
depRelDict[v] = i - 1
end
