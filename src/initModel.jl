#module InitModel

include("modelspec.jl")
export spec

function initModelSpec()::ModelSpec
    delimChar = '\t'
    vocabSize = 1200000
    spec = ModelSpec(delimChar,
        "us-east-1", # AWS region: N. Virginia, as recommended here: https://commoncrawl.org/2022/03/introducing-cloudfront-access-to-common-crawl-data/
        "s3://aktify-word-embeddings/",                     # s3bucket
        "/Users/irenelangkildegeary2015/data/word-embeddings/", # prefix of location to read/write files
        "input/kaikki.org-dictionary-English.json",         # vocabSource
        "input/part-m-00009",                               # tierSource, eg: "part-m-19038" 
        "model/tierKeys.tsv",                               # tierFile
        "model/wiktionaryVocab.tsv",                        # vocabFile
        "model/modelSpec.bson",                             # specFile
        "input/conll.paths",                                # udepFileList
        5,                                                  # numTiers
        20000,                                              # tierThreshold: frequency count of tier tuple for ending tier
        [3],                                                # tierIndices: first two elements are "<beginDoc>" and "<beginSen>", so tier 1 starts at index 3
        let tmp = Dict();   sizehint!(tmp, typemax(UInt8)); tmp end,  # tierDict
        let tmp = Vector(); sizehint!(tmp, typemax(UInt8)); tmp end,  # tier key List
        let tmp = Vector(); sizehint!(tmp, 16); tmp end,         # vocabDictVec
        let tmp = Vector(); sizehint!(tmp, vocabSize); tmp end,  # vocabList
        let tmp = Vector(); sizehint!(tmp, vocabSize); tmp end,  # lemmaList
        Dict(),           #vals
        #Vector(),        #domainVocabList
        #Vector(),        #domainLemmaList
        Dict{Symbol, Pair{Dict{String,<:UInt}, Vector{String}}}(), #catStrTransforms
        Vector(),         #featspecs
        Dict(),           #featspecDict
    )
    return spec
end
