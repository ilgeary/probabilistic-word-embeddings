#module InitModel

include("modelspec.jl")
export spec

function initModelSpec()::ModelSpec
    delimChar = '\t'
    vocabSize = 1200000
    beginDocTok = UdepTokenCore(; upos = 1)
    beginSenTok = UdepTokenCore(; upos = 2)
    spec =  ModelSpec(delimChar, beginDocTok, beginSenTok,
        "us-east-2", # (Ohio)                               # AWS region
        "s3://aktify-word-embeddings/",                     # s3bucket
        "~/data/",                                          # prefix of location to read/write files
        "word-embeddings/input/part-m-00009.gitignored",    # "part-m-19038" #tierSource
        "word-embeddings/input/kaikki.org-dictionary-English.json.gitignored",  #vocabSource
        "word-embeddings/model/tierKeys.tsv",               # tierFile
        "word-embeddings/model/wiktionaryVocab.tsv",        # vocabFile
        "word-embeddings/model/modelSpec.bson",             # specFile
        "word-embeddings/input/conll.paths",                # udepFileList
        5,                                                  # numTiers
        20000,                                              # tierThreshold: frequency count of tier tuple for ending tier
        [3],                                                # tierIndices: first two elements are "<beginDoc>" and "<beginSen>", so tier 1 starts at index 3
        let tmp = Dict(); sizehint!(tmp, typemax(UInt8)); tmp[beginDocTok]=0; tmp[beginSenTok]=1; tmp end,   #tierDict
        let tmp = [beginDocTok, beginSenTok]; sizehint!(tmp, typemax(UInt8)); tmp end,  #tier key List
        let tmp = Vector(); sizehint!(tmp, 16); tmp end,         #vocabDictVec
        let tmp = Vector(); sizehint!(tmp, vocabSize); tmp end,  #vocabList
        let tmp = Vector(); sizehint!(tmp, vocabSize); tmp end,  #lemmaList
        Dict(),          #vals
        #Vector(),        #domainVocabList
        #Vector(),        #domainLemmaList
        Dict{Symbol, Pair{Dict{String,<:UInt}, Vector{String}}}(), #catStrTransforms
        Vector(),        #featspecs
        Dict(),        #featspecDict
    )
    return spec
end

const spec = initModelSpec()

#end