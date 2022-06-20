# binarizeUdepcc.jl

using BSON

include("modelspec.jl")

if ! @isdefined spec
    const spec = BSON.load("/Users/irenelangkildegeary2015/data/word-embeddings/model/modelSpec.bson")[:a]
end

include("writeBinUdepcc.jl")
include("accessoryFeatDefs.jl")

struct VocabCode
    id0::UInt8
    id::UInt16
end

function isless(x1::VocabCode, x2::VocabCode)
    x1.id0 < x2.id0 || (x1.id0 == x2.id0 && x1.id < x2.id)
end

struct Docdat
    keyIds::Vector{UInt8}         # tier key integers
    tiers::Vector{UInt8}          # tier to which key belongs
    utoks::Vector{UdepTokenCore}  # core token info
    rightChildren::Vector{Vector{UInt8}}  # dependency tree structure info
    leftChildren::Vector{Vector{UInt8}} # dependency tree structure info
    treeOffsets::Vector{UInt8}    # dependency tree structure info
    vocabdat::Dict{UInt32, VocabCode} # holds freqs at first, and shortcode ID later
    shortcodes0::Vector{UInt8}    # position in vector is the shortcode ID for the given global vocab section code
    shortcodes::Vector{UInt16}    # position in vector is the shortcode ID for the given global vocab entry code 
    ix::Vector{UInt8}             # index vector used for sorting shortcodes
end

function Docdat()
    return Docdat(Vector(), Vector(), Vector(), Vector(), Vector(), Vector(), Dict(), Vector(), Vector(), Vector())
end

function resetDocdat(d)
    empty!(d.keyIds)
    empty!(d.tiers)
    empty!(d.utoks)
    empty!(d.rightChildren)  
    empty!(d.leftChildren)  
    empty!(d.treeOffsets)  
    empty!(d.vocabdat)
    empty!(d.shortcodes0)
    empty!(d.shortcodes)
    empty!(d.ix)
end

function pushKeyidTierUtok(d, keyId, tier, utok)
    push!(d.keyIds, keyId)
    push!(d.tiers, tier)
    push!(d.utoks, utok)
end

function pushTreeData(d, i)
    push!(d.rightChildren, Vector())
    push!(d.leftChildren, Vector())
    rootI = treeChildren(d, i)
    push!(d.treeOffsets, rootI)
    calcTreeOffsets(d, i)
end

# wget https://commoncrawl.s3.amazonaws.com/contrib
function encodeChunk(filename)
    docGroup = 0
    d = Docdat()
    i = 1   # index of start of sentence
    rootID = -1
    for line in eachline(filename)
        tok, rootID = conlluLineToUdepCore(line, rootID)
        tok == nullUtok && continue
        keyId, tier = getTierKeyId(tok, spec.numTiers)
        if tok == beginDocTok && length(d.utoks) > 0
            pushTreeData(d, i)
            #unigramBigramCounts(d)
            getShortCodes!(d)
            writeEncodedDoc(d, shortcodes)
            resetDocdat(d)
            if docGroup % (typemax(UInt8) + 1) == 0
                closeDocGroup
                newDocGroup()
                docGroup = 0
            end
            i = 1
            pushKeyIdTierUtok(d, keyId, tier, tok)
        elseif tok == beginSenTok
            if d.utoks[end] != beginDocTok
                pushTreeData(d, i)
                i = 1
                pushKeyIdTierUtok(d, keyId, tier, tok)
            end
        else 
            getTokenFeatureCounts(tok)
            vcode = VocabCode(tok.formLemma0, tok.formLemma)
            vocabdat[vcode] = get(vocabdat, vcode, 0) + 1
            pushKeyIdTierUtok(d, keyId, tier, tok)
        end
    end
    calcTreeOffsets(d, curSentStartPos)
    writeEncodedDoc(f, d)
end

function unigramBigramCounts(model, d)
    #for f in 
end

function treeChildren(d, i)
    root = i
    for tok in Iterators.rest(d.utoks, i)
        head = i+ tok.headOffset
        root == i && root = head
        tok.headOffset == 0 && continue
        tok.headOffset > 0 && push!(d.leftChildren[head], i)
        push!(d.rightChildren[head], i)
        i += 1
    end
    return root
end

function calcTreeOffset(d, i)
    i <= 0 && return 0
    ho = d.utoks[i].headOffset
    ho == 0 && return 0
    hi = i + ho
    if ho > 0
        leftCs = d.leftChildren[hi]
        y = findlast(x->x==i, leftCs)
        return length(leftCs) - y + 1
    else
        rightCs = d.rightChildren[hi]
        y = findfirst(x->x==i, rightCs)
        return -1 * y
    end
end

function calcTreeOffsets(d, i)
    for i in i0:length(d.toks)
        push!(d.treeOffsets, calcTreeOffset(d, i))
        i += 1
    end
end

function getShortCodes!(d)
    counts = sort(collect(values(vocabdat)), rev=true)
    maxS = findfirst(counts, 1) - 1   # there is no space benefit (actually a slight disadvantage) in giving singleton tokens a shortcode, so just write the global code to disk for those tokens
    if maxS >= 1
        maxDocShortCode = min(maxS, spec.vals[:maxShortCodes]) + 1
        minC = counts[maxDocShortCode]
        c2 = findfirst(counts, c) - 1
        n = maxDocShortCode - c2 
        numC = 0
        for (v,c) in pairs(vocabdat)
            if c > minC 
                push!(d.shortcodes0, v.id0)
                push!(d.shortcodes, v.id)
            elseif c == minC && numC < n 
                push!(d.shortcodes0, v.id0)
                push!(d.shortcodes, v.id)
                numC += 1
            end
        end
    end
    sortperm!(d.ix, 1:length(d.shortcodes), by=y->codeToId(d.shortcodes0[y], d.shortcodes[y]))
    for v in keys(vocabdat)
        vocabdat[v] = 0
    end
    for (i, j) in enumerate(d.ix)
        vocabdat[VocabCode(d.utoks[j].formlemma0, d.utoks[j].formlemma)] = i
    end
end

const granularityMap = Dict{Symbol, Vector{UInt8}}()

function makeGranularityMap()
    for enumerate(f,fspec) in spec.featspecs
        haskey(granularityMap, fspec.granularity) ?
            push!(granularityMap[fspec.granularity], i) :
            granularityMap[fspec.granularity] = [f]
    end
end

function tokenFeatCounts(t)
    for i in granularityMap["token"]
        val = spec.featspec[i].func(t)
end

function unigramBigramCounts(d)
end


encodeChunk("/Users/irenelangkildegeary2015//data/word-embeddings/input/part-m-00060")