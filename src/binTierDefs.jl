# binTierDefs.jl

include("udepConstructors.jl")
#include("modelspec.jl")

const maxTierKey = typemax(UInt8)

# TIERS
function Tier_1_Key(tok::UdepTokenCore)
    UdepTokenCore(tok.upos, tok.entity, tok.caps, tok.depRel, tok.headOffset, tok.formLemma0, tok.formLemma)
end
function Tier_2_Key(tok::UdepTokenCore)
    UdepTokenCore(tok.upos, tok.entity, tok.caps, tok.depRel, tok.headOffset, 0, 0)
end
function Tier_3_Key(tok::UdepTokenCore)
    UdepTokenCore(tok.upos, tok.entity, tok.caps, tok.depRel, nullTreeOffset, 0, 0)
end
function Tier_4_Key(tok::UdepTokenCore)
    UdepTokenCore(tok.upos, tok.entity, tok.caps, 0, nullTreeOffset, 0, 0)
end
function Tier_5_Key(tok::UdepTokenCore)
    UdepTokenCore(tok.upos, 0, 0, 0, nullTreeOffset, 0, 0)
end

const tierKeyFs = [Tier_1_Key, Tier_2_Key, Tier_3_Key, Tier_4_Key, Tier_5_Key]  # tierKeyFs

#=function Tier_2_Tuple(tok::UdepTokenCore, delimChar)
    l = length(tok.upos)
    if l >1 && SubString(tok.upos, 1, 2) in  ["CD", "JJ", "NN", "RB", "VB"]
        join([tok.upos, tok.entity, tok.caps, tok.depRel, tok.headOffset], delimChar)
    else
        join([tok.form, tok.lemma, tok.upos, tok.entity, tok.caps, tok.depRel], delimChar)
    end
end  =#

function getTierKey(tok, maxTierNum)
    #maxTierNum>0 && println("getTierKeyId:", maxTierNum, " ", tok )
    for t in 1:maxTierNum
        #println("u110:", tok, " ", x)
        keyTok = tierKeyFs[t](tok) #Eg: Tier_1_Tuple(tok)
        key = get(spec.tierDict, keyTok, maxTierKey)
        #println("u115 id:", id, " key:", key, " tier:", x)
        if (key < maxTierKey) key, t end
    end
    return maxTierKey, spec.numTiers + 1
end