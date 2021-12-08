# binarizeDepcc.jl

include("UDepUtils.jl") 

struct DocDat
    vocabCounts::Dict{String,UInt8}
    tier1VocabCounts::Dict{String,UInt8}
    toks::Vector{UdepToken}
    keys::Vector{UInt8}
    tiers::Vector{UInt8}
    treeOffsets::Vector{UInt8}
    vocabMap::Vector{Tuple{UInt8, UInt16, UInt8}}
end

function initDocDat()
    expNumRows = 5000
    return DocDat(
        let tmp = Dict(); sizehint!(tmp, expNumRows); tmp end,   # vocabCounts
        let tmp = Dict(); sizehint!(tmp, expNumRows); tmp end,   # tier1VocabCounts
        let tmp = Vector(); sizehint!(tmp, expNumRows); tmp end, # toks
        let tmp = Vector(); sizehint!(tmp, expNumRows); tmp end, # keys
        let tmp = Vector(); sizehint!(tmp, expNumRows); tmp end, # tiers
        let tmp = Vector(); sizehint!(tmp, expNumRows); tmp end  # treeOffsets
    )
end

function resetDocDat(d)
    empty!(d.vocabCounts)
    empty!(d.tier1VocabCounts)
    empty!(d.toks)
    empty!(d.keys)
    empty!(d.tiers)
    empty!(d.treeOffsets)    
end

function pushKeyTierUtokEtc(d, key, tier, tok)
    push!(d.keys, key)
    push!(d.tiers, tier)
    push!(d.toks, tok)
end

function conlluLineToTmpUdep(line, rootID, delimChar)
    cols = split(chomp(line), delimChar)
    rawtok = cols[2]
    caseT = caseType(rawtok)
    id = tryparse(UInt8, cols[1])
    id === nothing && error("Error: id===nothing:" * line)
    hid = tryparse(UInt8, cols[7])
    hid === nothing && error("Error: hid===nothing:" * line)
    depRel = cols[8]
    id == 0 && (rootID = -1)
    depRel == "ROOT" && (rootID = id)
    headOffset = if (depRel == "punct" && hid == rootID) 0 else Int8(hid) - Int8(id) end

        
function encodeChunk(spec)
    conlluLineToUdep = conlluLineToUdepF(spec.delimChar, spec.vocabDict)
    open(spec.tierSource) do f
        d= initDocDat()
        curSentStartPos = 1
        rootID = -1
        for line in eachline(f)
            length(line)<=0 && continue
            if line[1] == "# newdoc" && length(toks) > 0
                unigramBigramCounts(spec, d)
                encodeDoc(d)
                pushKeyTierUtokEtc(d, d.beginDocTok, 0, nullUtok)
            elseif line[1] == "# sent_id"
                calcTreeOffsets(d, curSentStartPos)
                curSentStartPos = length(d.keys) +1
                pushKeyTierUtokEtc(d, d.beginSenTok, 0, nullUtok)
            elseif line[1] == "#" 
                continue
            else
                tok, rootID = conlluLineToUdep(line, rootID)
                found, key, tier = getTierKey(tok, spec.tierDict, spec.numTiers)
                if !found 
                    key = typemax(UInt8)
                    tier = spec.numTiers + 1
                end
                pushKeyTierUtokEtc(d, key, tier, tok)
                getRowCounts(d)
                if tier == 1 
                    tier1VocabCounts[tok.form] = get(tier1VocabCounts, tok.form, 0) + 1
                else
                    vocabCounts[tok.form] = get(vocabCounts, tok.form, 0) + 1
                end
            end
        end
        encodeDoc(d)
    end
end

function getTierKey(tok, tierDict, numTiers)
    found =false
    tier = numTiers +1
    for x in 1:numTiers
        key = tierKeyFs[x](tok) #Eg: Tier_1_Tuple(tok)
        if haskey(spec.tierDict, key)
            found = true
            tier = x
            break
        end
    end
    return found, key, tier
end

#=struct DocDat
vocabCounts::Dict{String,UInt8}
tier1VocabCounts::Dict{String,UInt8}
toks::Vector{UdepToken}
keys::Vector{UInt8}
tiers::Vector{UInt8}
treeOffsets::Vector{UInt8}
vocabMap::Vector{Tuple{UInt8, UInt16, UInt8}}
end=#

#function unigramBigramCounts(spec, d)
#    
#end

function getVocabMap(spec, d)
    s = sort(collect(d.vocabCounts), rev=true, by=x->getindex(x,2))
    for (i,v) in enumerate(s)
        vi0, vi = globalVocabId(spec.vocabDict, v)
    end

end

function encodeDoc(f, spec, vocabDicts, keys, tiers, toks)
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