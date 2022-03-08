# binarizeDepcc.jl

using BSON
include("accessoryFeatDefs.jl")

#const spec = BSON.load("test.bson")

struct VocabCode
    id0::UInt8
    id::UInt16
end

function isless(x1::VocabCode, x2::VocabCode)
    x1.id0 < x2.id0 || (x1.id0 == x2.id0 && x1.id < x2.id)
end

struct Docdat
    keys::Vector{UInt8}           # tier key integers
    tiers::Vector{UInt8}          # tier to which key belongs
    utoks::Vector{UdepTokenCore}  # core token info
    rightChildren::Vector{UInt8}  # dependency tree structure info
    leftChildren::Vector{Vector{UInt8}} # dependency tree structure info
    treeOffsets::Vector{Vector{UInt8}}  # dependency tree structure info
    vocabdat::Dict{UInt32, VocabCode} # holds freqs at first, and shortcode ID later
    shortcodes0::Vector{UInt8}    # position in vector is the shortcode ID for the given global vocab section code
    shortcodes::Vector{UInt16}    # position in vector is the shortcode ID for the given global vocab entry code 
    ix::Vector{UInt8}             # index vector used for sorting shortcodes
end

function Docdat()
    return DocDat(Vector(), Vector(), Vector(), Vector(), Vector(), Vector(), Dict(), Vector(), Vector(), Vector())
end

function resetDocDat(d)
    empty!(d.keys)
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

function pushKeyTierUtokEtc(d, key, tier, tok)
    push!(d.keys, key)
    push!(d.tiers, tier)
    push!(d.toks, tok)
end

# wget https://commoncrawl.s3.amazonaws.com/contrib
function encodeChunk(filename)
    docGroup = 0
    docdat = initDocDat()
    i = 0
    curSentStartPos = 0
    rootID = -1
    for line in eachline(filename)
        length(line)<=0 && continue
        if line[1] == "# newdoc" && length(toks) > 0
            #unigramBigramCounts(docdat)
            getShortCodes!(d)
            writeEncodedDoc(docdat, shortcodes)
            resetDocDat(docdat)
            push!(d.treeOffsets, 0)
            i = 0
            if docGroup % (typemax(UInt8) + 1) == 0
                writeDocGroup()
                docGroup = 0
            end
        elseif line[1] == "# sent_id"
            treeChildren(docdat, curSentStartPos)
            calcTreeOffsets(docdat, curSentStartPos)
            i += 1
            curSentStartPos = i
            pushKeyTierTokEtc(docdat, docdat.beginSenTok, 0, nullUtok, "", ())
        elseif line[1] == "#" 
            continue
        else 
            i += 1
            tok, rootID = conlluLineToUdepCore(line, rootID)
            found, key, tier = getTierKey(tok, spec.numTiers)
            if !found 
                key = typemax(UInt8)
                tier = spec.numTiers + 1
            end
            pushKeyTierUtokEtc(docdat, key, tier, tok)
            getTokenFeatureCounts(tok)
            vcode = VocabCode(tok.formLemma0, tok.formLemma)
            if tier > 1 && tok.formLemma0 > 0
                vocabdat[vcode] = get(vocabdat, vcode, 0) + 1
            end
        end
    end
    calcTreeOffsets(d, curSentStartPos)
    writeEncodedDoc(f, d)
end

function unigramBigramCounts(model, d)
    #for f in 
end

function treeChildren(d, start=1)
    for (i, tok) in enumerate(d.toks[start])
        tok.headOffset == 0 && continue
        tok.headOffset > 0 && push!(d.leftChildren[i+ tok.headOffset], i)
        push!(d.rightChildren[i+ tok.headOffset], i)
    end
end

function calcTreeOffset(d, i)
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

function calcTreeOffsets(d, init=1)
    for i in init:length(d.toks)
        push!(d.treeOffsets, calcTreeOffset(d, i))
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
        vocabdat[VocabCode(docdat.utoks[j].formlemma0, docdat.utoks[j].formlemma)] = i
    end
end


encodeChunk("~/data/word-embeddings/input/part-m-00009.gitignored")