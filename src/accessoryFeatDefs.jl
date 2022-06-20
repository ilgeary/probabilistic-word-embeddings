# accessoryFeatDefs.jl

include("binTierDefs.jl")

function setupBasePOS()
    uposDict = spec.catStrTransforms[:upos][1]
    basePosDict = Dict{String, UInt8}()
    for (v, i) in pairs(uposDict)
        startswith(v, "J") ? basePosDict[i] = uposDict["JJ"] :
        startswith(v, "N") || startswith(v, "CD") ? basePosDict[i] = uposDict["NN"] :
        startswith(v, "RB") ? basePosDict[i] = uposDict["RB"] :
        startswith(v, "V") ? basePosDict[i] = uposDict["VB"] :
        basePosDict[i] = i
    end
    spec.catStrTransforms[:basePOS] = Pair(basePosDict, spec.catStrTransform[:upos])
end

const agreementNumberNone       = 0
const agreementNumberSingular   = 1
const agreementNumberPlural     = 2
const agreementNumberAmbiguous  = 3

const agreementNumberVals = [
    "singular",
    "plural",
    "ambiguous"
]

# Agreement between verbs and nouns
const agreementNumberDict = Dict{UInt8,UInt8}() 

function setupNumber()
    uposDict = spec.catStrTransforms[:upos][1]
    agreementNumberDict = Dict{String, UInt8}()
    for (v, i) in pairs(uposDict)
        v in ["CD"] ? agreementNumberDict[i]            = agreementNumberAmbiguous :  # ambiguous, eg: "one" vs. "two"
        v in ["NN", "NNP"] ? agreementNumberDict[i]     = agreementNumberSingular :   # singular
        v in ["NNPS", "NNS"] ? agreementNumberDict[i]   = agreementNumberPlural :     # plural
        v in ["VBP"] ? agreementNumberDict[i]           = agreementNumberPlural :     # plural
        v in ["VBZ"] ? agreementNumberDict[i]           = agreementNumberSingular :   # singular
        agreementNumberDict[i]                          = agreementNumberNone         # irrelevant
    end
    spec.catStrTransforms[:number] = Pair(numberDict, agreementNumberVals)
end

const singularCDstrs = ("one", "1", "1.0", "1.00")
const singularCDs = map(x->globalVocabCode(x), singularCDstrs)

function number(tok) 
    n = get(agreementNumberDict, tok.upos, 0)
    if n == agreementNumberAmbiguous 
        if findfirst(code->code[1]==tok.formlemma0 && code[2] == tok.formlemma, singularCDs) !== nothing
            return agreementNumberSingular
        else return agreementNumberPlural
        end
    else return n
    end
end

function genInitFeatList()
    initFeatList = Vector{Tuple{Feature}}()
    for f in spec.featspec
        push!(initFeatList, f.name)
    end
    for r in [rightNeighbor, leftNeighbor, head, rightSibling, leftSibling]
        for f in spec.featspec
            push!(initFeatList, (r, f.name))
            push!(initFeatList, (r, r, f.name))
        end
    end
    for r in [sameSen, sameDoc] 
        for f in (form, lemma)
            push!(initFeatList, (r, f))
        end
    end
    return initFeatList
end
