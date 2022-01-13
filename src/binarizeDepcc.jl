# binarizeDepcc.jl

include("UDepUtils.jl") 

struct DocDat
    keys::Vector{UInt8}
    tiers::Vector{UInt8}
    toks::Vector{UdepToken}
    treeOffsets::Vector{UInt8}
    vocabCounts::Dict{String,UInt8}
    vocabIndex::Dict{String, Vector{UInt}}
end
        
function initDocDat()
    expNumRows = 5000
    return DocDat(
        let tmp = Vector(); sizehint!(tmp, expNumRows); tmp end, # keys
        let tmp = Vector(); sizehint!(tmp, expNumRows); tmp end, # tiers
        let tmp = Vector(); sizehint!(tmp, expNumRows); tmp end, # toks
        let tmp = Vector(); sizehint!(tmp, expNumRows); tmp end, # treeOffsets
        let tmp = Dict(); sizehint!(tmp, expNumRows); tmp end,   # vocabCounts
        let tmp = Dict(); sizehint!(tmp, expNumRows); tmp end    # vocabIndex
        )
end

function resetDocDat(d)
    empty!(d.keys)
    empty!(d.tiers)
    empty!(d.toks)
    empty!(d.treeOffsets)  
    empty!(d.vocabCounts)
end

function pushKeyTierUtokEtc(d, key, tier, tok, form, cc)
    push!(d.keys, key)
    push!(d.tiers, tier)
    push!(d.toks, tok)
end

function encodeDataset(spec, model) ## add for loop
    conlluLineToUdepFull = conlluLineToUdepFullF(spec.delimChar, spec.vocabDict)
    encodeChunk(spec, model, conlluLineToUdepFull)
end

function encodeChunk(spec, docdat, conlluLineToUdepFull)
    open(spec.tierSource) do f
        docdat = initDocDat()
        curSentStartPos = 1
        rootID = -1
        for line in eachline(f)
            length(line)<=0 && continue
            if line[1] == "# newdoc" && length(toks) > 0
                unigramBigramCounts(docdat)
                writeEncodedDoc(docdat)
                pushKeyTierTokEtc(docdat, docdat.beginDocTok, 0, nullUtok, "", ())
                push!(d.treeOffsets, 0)
                i = 0
            elseif line[1] == "# sent_id"
                i += 1
                calcTreeOffsets(docdat, curSentStartPos)
                curSentStartPos = length(d.keys) +1
                pushKeyTierTokEtc(docdat, docdat.beginSenTok, 0, nullUtok, "", ())
            elseif line[1] == "#" 
                continue
            else
                i += 1
                tokFull, rootID = conlluLineToUdepFull(line, rootID)
                found, key, tier = getTierKey(tok, spec.tierDict, spec.numTiers)
                if !found 
                    key = typemax(UInt8)
                    tier = spec.numTiers + 1
                end
                pushKeyTierTokEtc(docdat, key, tier, tokFull)
                #getRowCounts(d)
                tier > 1 && (docdat.vocabCounts[tok.form] = get(docdat.vocabCounts, tok.form, 0) + 1)
                #docdat.vocabIndex[tok.form] = get(docdat.vocabIndex, tok.form, UInt[]) + i
                end
            end
        end
        calcTreeOffsets(d, curSentStartPos)
        writeEncodedDoc(d)
    end
end

function unigramBigramCounts(model, d)
    #for f in 
end

function getVocabMap(spec, d)
    s = sort(collect(d.vocabCounts), rev=true, by=x->getindex(x,2))
    maxI = typemax(UInt8) + 1 - length(spec.vocabDictVec)
    for (i,v) in enumerate(s)
        vi0, vi = globalVocabId(spec.vocabDict, v)
    end

end

function writeEncodedDoc(f, spec, vocabDicts, keys, tiers, toks)
    docVocabList = Vector{UInt8}()
    localIdMax = min(length(s), typemax(UInt8)-length(spec.vocabDict))
    for (i, tok) in enumerate(s)
        i > localIdMax && break
        vocabDict[tok] = i
    end
    write(f, UInt8(0), UInt8(i))
    v = Vector{UInt8}()
    for (k, tier, tok) in zip(keys, tiers, toks)
        if tier>1 globalVocabId(spec.vocabDict, tok)
        write(f, k, encodeRow(k, tier, tok))
    end
end

function encodeRow(key, tier, tok)

end
#=
struct DocDat
    keys::Vector{UInt8}
    tiers::Vector{UInt8}
    toks::Vector{UdepToken}
    forms::Vector{String}
    casings::Vector{Tuple{Vararg{UInt8}}}
    treeOffsets::Vector{UInt8}
    vocabCounts::Dict{String,UInt8}
    vocabMap  #globalID2localId
end
=#

function writeWordForm(f, tok)
    b = write(f, form0)
    b += if tok.base.form0 == 0
        write(f, tok.formStr)
    else write(f, tok.form)
    end
end

struct Tier_1_tok
    key::UInt8
end

struct Tier_2_tok
    key::UInt8
    form::WordForm
end

struct Tier_3_tok
    key::UInt8
    headOffset::Int8
    form::WordForm
end

struct Tier_4_tok
    key::UInt8
    depRel::UInt8
    headOffset::Int8
    form::WordForm
end

struct Tier_5_tok
    key::UInt8
    entity::UInt8
    depRel::UInt8
    headOffset::Int8
    form::WordForm
end

# Tier "6" (key 255) UdepTok
struct Tier_6_tok
    key::UInt8
    pos::UInt8
    entity::UInt8
    depRel::UInt8
    headOffset::Int8
    form::WordForm
end

s1, id1, next
s2, id2, next
k1, next
k2, next
k1, s1, id1, next #top frequency words
s2, id2
k3,

0, "token"


function writeTier_1_Tok(f, d, i)
    write(f, d.keys[i])
end

function writeVocabElem(f, tok, form)
    fId = formId(tok.form0, tok.form)
    if fId > 0
        if haskey(vocabMap, fId)
            write(f, vocabMap[fId])
        else
            write(f, tok.form0, tok.form)
        end
    else write(f, form, UInt8(0))
end

function writeTier_2_Tok(f, d, i)
    write(f, d.keys[i])
    writeVocabElem(f, d.toks[i], d.forms[i])
end

function writeTier_3_Tok(f, d, i)
    if tok.headOffset == typemax(Int8)
        write(f, UInt8(0))
    else write(f, tok.headOffset + abs(typemin(Int8)))
    end
end

"""
<startDoc> 8 [length shortcode list]
8 <8 8> 8 [globalVocabId nextLoc]
....    [256-max length(vocabDictVec)]
tierKey
...     [length(sent)]





vocab
======
t(tier1)
8  shortcode (0-242)
8 8 8 globalId 243-256, 0-2^16