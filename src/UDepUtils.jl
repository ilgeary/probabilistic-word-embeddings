# Utilities for dealing with UDep data

using Unicode
# using StructIO

const mainPath = "/Users/irenelangkilde-geary/Projects/UDepParse/model/"  # mainPath

struct UdepToken
    form::String
    lemma::String
    upos::String
    entity::String
    caseType::String
    depRel::String
    headOffset::Int8
end

struct ModelSpec
    delimChar::Char
    datPath::String
    tierSource::String
    tierFile::String
    specFile::String
    numTiers::UInt8
    tierThreshold::UInt
    tierIndices::Vector{UInt8}
    tierDict::Dict{String,UInt8}
    tierList::Vector{String}
end

struct Model
    tierDict::Dict{String,UInt8}
    tierList::Vector{String}
    vocabDict::Dict{String,UInt16}
    vocabList::Vector{String}
end

# TIERS
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

const tierKeyF0s = [Tier_1_Tuple, Tier_2_Tuple, Tier_3_Tuple, Tier_4_Tuple, Tier_5_Tuple]  # tierKeyFs
function getTierKeyFs(delimChar)       
    [function (x) f(x, delimChar) end for f in tierKeyF0s]
end

# map a line in CoNLL-U Format to UdepToken struct
function conlluLineToUdep(line, rootID, delimChar)
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
    return UdepToken(
        lowercase(cols[2]), # form
        lowercase(cols[3]), # lemma
        cols[4],            # upos
        cols[10],           # entityType
        caseT,              # caseType
        depRel,             # depRel
        headOffset),        # headOffset
    rootID
end

function caseType(str)
    uc = 0
    uc_ = 0
    lc = 0
    nonletter = false
    custom = ""
    for g in graphemes(str)
        c = g[1]
        if islowercase(c)
            lc += 1
            nonletter = false
            custom = custom * 'q'
        elseif isuppercase(c) 
            uc += 1
            if (nonletter) uc_ += 1 end
            nonletter = false
            custom = custom * 'Q'
        else 
            nonletter = true
            custom = custom * '.'
        end
    end  
    if (uc == 0)                                        "none"
    elseif (uc == 1 && custom[1] == 'Q')                "1st"
    elseif (uc == 1 && custom[2] == 'Q')                "2nd"
    # elseif (uc ==1 && custom[3] =='Q')                "3rd"
    elseif (uc == uc_+1 && custom[1] == 'Q')            "title" 
    elseif (uc == uc_)                                  "camel"
    elseif (uc >= 1 && lc == 0)                         "all"
    elseif (uc >= 1 && lc == 1 && str[end] == 's')      "allPlural"
    else                                                "custom:" * String(custom)
    end
end

function isvalid(str)
    str != "" && !occursin(r"^\s", str) && isascii(str)
end 


#= 
function readVocabDict()
    iCounts = Dict{String,UInt}()
    open(mainPath * "alphaSorted-enwiki-20190320-words-frequency.txt") do f
        c=0
        for line in eachline(f)
            (line < "a-" || line > "zzzzzzzzzzz" || !isascii(line)) && continue
            c += 1
            if c >= typemax(UInt16) 
                println(line)
                c = 0
            end
        end
    end
end =#
#=            l = split(line, " ")
            k0 = l[1]
            i2 = thisind(k0, firstindex(k0)+1)
            i = min(lastindex(k0), i2)
            k = SubString(k0, firstindex(k0), i)
            #k = UInt8(char2Group(k0, line))
            isascii(k) && (iCounts[k] = get(iCounts, k, 0) + 1)
        end
    end
    x=0
    i=1
    for (k,c) in sort(collect(iCounts))
        println(i, " ", k, " ", c)
        x += c
        i += 1
        if x > typemax(UInt16) 
            x=0
            println("65K!!!")
        end
    end
    println("Len: ", length(iCounts))
end

function char2Group(k0, line)
    if k0 < ' '
        #println("Unexpected char:", k0, ". ", line)
        0
    elseif k0 < '0' 
        '!'
    elseif k0 <= '9'
        '0'
    elseif k0 < 'A'
        '!'
    elseif k0 <= 'Z'
        lowercase(k0)
    elseif k0 < 'a'
        '!'
    elseif k0 <= 'z'
        k0
    elseif k0 <= '~'
        '!'
    else
        #println("Unexpected char:", k0, ". ", line)
        0
    end
end =#

# @time readVocabDict()

# end            