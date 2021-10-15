# Utilities for dealing with UDep data

#module UDepUtils
#export UdepToken, conlluLineToUdep, caseType 
#export Tier_1_Tuple, Tier_2_Tuple, Tier_3_Tuple, Tier_4_Tuple, Tier_5_Tuple

using Unicode

struct UdepToken
    form    #String
    lemma   #String
    upos    #String
    entity  #String
    caseType #String
    depRel  #String
    headOffset #Int
end

# map a line in CoNLL-U Format to UdepToken struct
function conlluLineToUdep(line, rootID)
    cols = split(chomp(line), "\t")
    rawtok = cols[2]
    caseT = caseType(rawtok)
    form = if (caseT != "custom") lowercase(rawtok) else rawtok end
    id = tryparse(UInt8, cols[1])
    id === nothing && error("Error: id===nothing:" * line)
    hid = tryparse(UInt8, cols[7])
    hid === nothing && error("Error: hid===nothing:" * line)
    depRel = cols[8]
    id == 0 && (rootID = -1)
    depRel == "ROOT" && (rootID = id)
    depRel == "punct" && hid == rootID && (headOffset = "0")
    return UdepToken(form,      #form
        lowercase(cols[3]), #lemma
        cols[4],            #upos
        cols[10],           #entityType
        caseT,              #caseType
        depRel,             #depRel
        string(Int8(hid) - Int8(id))), #headOffset
    rootID
end

#= TIERS
0 = Start-of-doc-and-sentence
1 = start-of-sentence
Tier 1: 2 - 64 =        top 62 tuples: token+baseForm+upos+entityType+capsType+headRel+headOffset
Tier 2: 65 - 192 =      top 128 tuples: upos+entityType+capsType+headRel+headOffset [+ token + baseForm]
Tier 3: X-x = top 60:   upos+entityType  [[capsType +headRel+headOffset] + [token + baseForm]]
=#

function Tier_1_Tuple(tok::UdepToken, delimChar)
    join([tok.form, tok.lemma, tok.upos, tok.entity, tok.caseType, tok.depRel, tok.headOffset], delimChar)
end

function Tier_2_Tuple(tok::UdepToken, delimChar)
    join([tok.upos, tok.entity, tok.caseType, tok.depRel, tok.headOffset], delimChar)
end

function Tier_3_Tuple(tok::UdepToken, delimChar)
    join([tok.upos, tok.entity, tok.caseType, tok.depRel], delimChar)
end

function Tier_4_Tuple(tok::UdepToken, delimChar)
    join([tok.upos, tok.entity, tok.caseType], delimChar)
end

function Tier_5_Tuple(tok::UdepToken, delimChar)
    join([tok.upos], delimChar)
end

function caseType(str)
    uc = 0
    uc_ = 0
    lc = 0
    nonletter = false
    t = map(graphemes(str)) do c 
        if islowercase(c[1])
            lc += 1
            nonletter = false
            'q'
        elseif isuppercase(c[1]) 
            uc += 1
            if (nonletter) uc_ += 1 end
            nonletter = false
            'Q'
        else 
            nonletter = true
            c
        end
    end  
    if (uc == 0)                                    "none"
    elseif (t[1] =='Q' && uc == 1)                  "1st"
    elseif (length(t)>=2 && t[2] =='Q' && uc == 1)  "2nd"
    #elseif (length(t)>=3 && t[3] =='Q' && uc == 1)  "3rd"
    elseif (t[1] =='Q' && uc_ == uc-1)              "title" 
    elseif (uc_ == uc)                              "camel"
    elseif (lc == 0)                                "all"
    elseif (uc>=1 && lc==1 && t[length(t)] == 'q')  "allPlural"
    else                                            "custom"
    end
end


#end