# binTierDefs.jl

include("udepConstructors.jl")
#include("modelspec.jl")

# TIERS
function Tier_1_Key(tok::UdepTokenCore)
    UdepTokenCore(tok.upos, tok.entity, tok.caps, tok.depRel, tok.headOffset, tok.formLemma0, tok.formLemma)
end
function Tier_2_Key(tok::UdepTokenCore)
    UdepTokenCore(tok.upos, tok.entity, tok.caps, tok.depRel, tok.headOffset, 0, 0)
end
function Tier_3_Key(tok::UdepTokenCore)
    UdepTokenCore(tok.upos, tok.entity, tok.caps, tok.depRel, typemax(Int8), 0, 0)
end
function Tier_4_Key(tok::UdepTokenCore)
    UdepTokenCore(tok.upos, tok.entity, tok.caps, 0, typemax(Int8), 0, 0)
end
function Tier_5_Key(tok::UdepTokenCore)
    UdepTokenCore(tok.upos, 0, 0, 0, typemax(Int8), 0, 0)
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

function getTierKeyId(tok, maxTierNum)
    #maxTierNum>0 && println("getTierKeyId:", maxTierNum, " ", tok )
    for x in 1:maxTierNum
        #println("u110:", tok, " ", x)
        key = tierKeyFs[x](tok) #Eg: Tier_1_Tuple(tok)
        id = get(spec.tierDict, key, 0)
        #println("u115 id:", id, " key:", key, " tier:", x)
        if (id > 0) return id, key, x end
    end
    return 0, nullUtok, 0
end