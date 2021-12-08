# Utilities for dealing with UDep data

using Unicode, BenchmarkTools
# using StructIO

struct UdepToken 
    upos::UInt8
    entity::UInt8
    caseType::UInt8
    depRel::UInt8
    headOffset::Int8
    formlemma0::UInt8   # section id
    formlemma::UInt16   # id within section
end

function bin2Pretty(x::UdepToken, vocabList)
#    println("Form-and-lemma:", x.formlemma0, " ", x.formlemma, " key:", x.formlemma0>0 && vocabDictVec[x.formlemma0].key)
    join(["upos:", x.upos>0 ? UposVals[x.upos] : "<null>", 
        " entity:", x.entity>0 ? EntityVals[x.entity] : "<null>", 
        " caseType:", x.caseType>0 ? CasetypeVals[x.caseType] : "<null>",
        " depRel:", x.depRel>0 ? DepRelVals[x.depRel] : "<null>",
        " headOffset:", string(x.headOffset),
        " form-and-lemma:", x.formlemma0>0 && x.formlemma>0 ? vocabList[(x.formlemma0-1)*sizeof(UInt16)+x.formlemma] : "<null>"],
        ' ')
end

struct UdepTokenCustomCase
    tok::UdepToken
    case::Tuple{Vararg{UInt8}}
end

function bin2Pretty(x::UdepTokenCustomCase)
    strType = CasetypeVals[x.tok.caseType]
    bin2Pretty(x.tok) * " casePattern:", (startswith(strType, "custom") ? ('-' * join(map(y->reverse(bitstring(y)), x.case), '-')) : "")
end

const nullUtok = UdepTokenCustomCase(UdepToken(0, 0, 0, 0, 0, 0, 0), ())

struct VocabEntry
    form::String
    lemma::String
end

import Base.isless
Base.isless(a::VocabEntry, b::VocabEntry) = a.form < b.form || (a.form == b.form && a.lemma < b.lemma)

struct OovUdepToken #<: AbstractToken
    udepTok::UdepToken
    oovTok::Union{Nothing, VocabEntry}
end

struct VocabSection   # used by ModelSpec's vocabDictVec
    key::VocabEntry
    dict::Dict{VocabEntry, UInt16}
end

struct ModelSpec
    delimChar::Char     # typically tab for natural language data
    beginDocTok::UdepToken # symbol used to mark the start of a new doc and sentence
    beginSenTok::UdepToken # symbol used to mark the start of a new sentence
    awsRegion::String   # region of s3 bucket containing input data from wiktionary and single depcc chunk used for setting up tiers
    s3bucket::String    # name of bucket containing input data used to setup binarization
    tierSource::String  # name of single depcc chunk used to setup feature combo tiers
    vocabSource::String # name of vocab source file, eg. derived from wikitionary
    tierFile::String    # name of output file that stores list of tiers
    vocabFile::String   # name of output file that stores global form+lemma vocab entries
    specFile::String    # name of file that stores bindings for this ModelSpec
    numTiers::UInt8     # number of feature combo sets organized by frequency, with fewer bytes associated with lower tiers
    tierThreshold::UInt # frequency level used as threshold between tiers
    tierIndices::Vector{UInt8}          # vector with numTiers entries ranging from 2-256 indicating the starting indices of each tier
    tierDict::Dict{UdepToken, UInt8}    # maps feature combo to tier number for high frequency feature combos
    tierList::Vector{UdepToken}         # ordinal list of tiered feature combos
    vocabDictVec::Vector{VocabSection}  # map token strings of global voacb to integers
    vocabList::Vector{VocabEntry}       # ordinal list of global vocab
end

# TIERS
function Tier_1_Key(tok::UdepToken)
    UdepToken(tok.upos, tok.entity, tok.caseType, tok.depRel, tok.headOffset, tok.formlemma0, tok.formlemma)
end
function Tier_2_Key(tok::UdepToken)
    UdepToken(tok.upos, tok.entity, tok.caseType, tok.depRel, tok.headOffset, 0, 0)
end
function Tier_3_Key(tok::UdepToken)
    UdepToken(tok.upos, tok.entity, tok.caseType, tok.depRel, 0, 0, 0)
end
function Tier_4_Key(tok::UdepToken)
    UdepToken(tok.upos, tok.entity, tok.caseType, 0, 0, 0, 0)
end
function Tier_5_Key(tok::UdepToken)
    UdepToken(tok.upos, 0, 0, 0, 0, 0, 0)
end

const tierKeyFs = [Tier_1_Key, Tier_2_Key, Tier_3_Key, Tier_4_Key, Tier_5_Key]  # tierKeyFs

#=function Tier_2_Tuple(tok::UdepToken, delimChar)
    l = length(tok.upos)
    if l >1 && SubString(tok.upos, 1, 2) in  ["CD", "JJ", "NN", "RB", "VB"]
        join([tok.upos, tok.entity, tok.caseType, tok.depRel, tok.headOffset], delimChar)
    else
        join([tok.form, tok.lemma, tok.upos, tok.entity, tok.caseType, tok.depRel], delimChar)
    end
end  =#

function getTierKeyId(tierDict, tok, maxTierNum)
    for x in 1:maxTierNum
        key = tierKeyFs[x](tok) #Eg: Tier_1_Tuple(tok)
        id = getkey(tierDict, key, 0)
        if (id > 0) return id, key end
    end
    return 0, nullUtok
end

function globalVocabId(vocabDictVec, vocabEntry)
    imax = length(vocabDictVec)
    str = vocabEntry.form
    i0 = max(1, Int(trunc((Int(str[1]) - Int('a') +1)/(26/imax))))
    i = min(i0, imax)
    while i > 1 && vocabEntry < vocabDictVec[i].key
        i -= 1
    end
    while i+1 < imax && vocabEntry >= vocabDictVec[i+1].key
        i += 1
    end
    v = get(vocabDictVec[i].dict, vocabEntry, 0)
    v > 0 && return i, v
    return 0, 0
end

# map a line in CoNLL-U Format to UdepToken struct
function conlluLineToUdepF(delimChar, vocabDictVec)
    function (line, rootID)
        cols = split(chomp(line), delimChar)
        rawtok = cols[2]
        caseT, customCase = caseType(rawtok)
        id = tryparse(UInt8, cols[1])
        id === nothing && error("Error: id===nothing:" * line)
        hid = tryparse(UInt8, cols[7])
        hid === nothing && error("Error: hid===nothing:" * line)
        depRel = cols[8]
        id == 0 && (rootID = -1)
        depRel == "ROOT" && (rootID = id)
        headOffset = if (depRel == "punct" && hid == rootID) 0 else Int8(hid) - Int8(id) end
        fl = VocabEntry(lowercase(cols[2]), lowercase(cols[3]))
        i, v = globalVocabId(vocabDictVec, fl)
        return UdepTokenCustomCase(
            UdepToken(
                UposDict[cols[4]],          # upos           45 values
                EntityDict[cols[10]],       # entityType      7 values
                CasetypeDict[caseT],        # caseType       15 values
                DepRelDict[depRel],         # depRel         50 values
                headOffset,                 # headOffset    256 values (+/- 128)
                i,                          # vocab section ~17 values
                v),                         # vocab ID    65536 values
                customCase),                # bit pattern for custom capitalization: 0-7 bytes
        rootID
    end
end

function checkbit(s::Vector{UInt8}, n)
    n > length(s) * 8 && return false
    j = Int(ceil(n / 8))
    k = (n - 8(j-1))
    #println("j:",j, " k:", k, " s[j]:", bitstring(s[j]), " >>:", bitstring(s[j] >> (k-1)))
    (s[j] >> (k-1)) & UInt8(1) != 0
end

# Determine the pattern of uppercase-ness for str.  
# type values must correspond exactly with CasetypeVals
function caseType(str)
    uc = 0
    uc_ = 0  # count of uppercase graphemes which follow a non-letter.
    lc = 0
    nonletter = false
    maxBits = 8 * 7  # up to seven bytes (56 graphemes) allotted for custom case patterns
    custom = UInt8[]
    for (i, g) in enumerate(graphemes(str))
        i> maxBits && break  
        c = g[1]
        if islowercase(c)
            lc += 1
            nonletter = false
        elseif isuppercase(c) 
            uc += 1
            if (nonletter) uc_ += 1 end
            nonletter = false
            j = Int(ceil(i / 8))
            for l in length(custom)+1:j
                push!(custom, UInt8(0))
            end
            k = (i - 8(j-1))
            custom[j] |= 1<<(k-1)
        else 
            nonletter = true
        end
    end  
    extraBytes = UInt8[]
    t = if (uc == 0)                                     "none"        
    elseif (uc == 1     && checkbit(custom, 1) == 1)     "1st"
    elseif (uc == 1     && checkbit(custom, 2) == 1)     "2nd"
    elseif (uc == 1     && checkbit(custom, 3) == 1)     "3rd"
    elseif (uc == uc_+1 && checkbit(custom, 1) == 1)     "title" 
    elseif (uc == uc_)                                   "camel"
    elseif (uc >= 1 && lc == 0)                          "all"
    elseif (uc >= 1 && lc == 1 && islowercase(str[end])) "allButLast"
    else   extraBytes = map(htol, custom);               "custom:" * string(length(custom))
    end            #htol (host-to-littleEndian) to maintain functionality across Mac vs Windows, etc.
    return t, Tuple{Vararg{UInt8}}(extraBytes)
end

function isvalid(str)
    str != "" && !occursin(r"^\s", str) && isascii(str)
end 

function readTierInfo(model)
    tierDict = model.tierDict
    tierList = model.tierList
    open(spec.tierFile) do f
        for (i0, line) in enumerate(eachline(f))
            i = i0 + 2
            k = chop(line)
            tierDict[k] = i
            push!(tierList, k)
        end
    end
    println("Done loading tier info!", sum)
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
=#

function calcTreeOffsets(d, start=1)
    for i in start:length(d.toks)
        if d.toks[i].headOffset == 0
            push!(d.treeOffsets, 0)
        else
            s = sign(tok.headOffset)
            headId = i + tok.headOffset
            o=0
            for j in i+s : s : i + tok.headOffset - s
                j + d.toks[j].headOffset == headId && (o += 1)
            end
            push!(d.treeOffsets, o*sign)
        end
    end
end

const EntityVals = [ # 7 vals
    "B-Location",
    "B-Organization",
    "B-Person",
    "I-Location",
    "I-Organization",
    "I-Person",
    "O"
]

const EntityDict= Dict{String,UInt8}() 
for (i, v) in enumerate(EntityVals)
    EntityDict[v] = i
end

const CasetypeVals = [ # 15 vals
    "none",
    "1st",
    "2nd",
    "3rd",
    "title",
    "camel",
    "all",
    "allButLast",
    "custom:1",
    "custom:2",
    "custom:3",
    "custom:4",
    "custom:5",
    "custom:6",
    "custom:7"
]

const CasetypeDict= Dict{String,UInt8}() 
for (i, v) in enumerate(CasetypeVals)
    CasetypeDict[v] = i
end

const UposVals = [ # 45 vals plus two boundary markers
    "<beginDoc>",
    "<beginSen>",
    "#",
    "\$",
    "''",
    ",",
    "-LRB-",
    "-RRB-",
    ".",
    ":",
    "CC",
    "CD",
    "DT",
    "EX",
    "FW",
    "IN",
    "JJ",
    "JJR",
    "JJS",
    "LS",
    "MD",
    "NN",
    "NNP",
    "NNPS",
    "NNS",
    "PDT",
    "POS",
    "PRP",
    "PRP\$",
    "RB",
    "RBR",
    "RBS",
    "RP",
    "SYM",
    "TO",
    "UH",
    "VB",
    "VBD",
    "VBG",
    "VBN",
    "VBP",
    "VBZ",
    "WDT",
    "WP",
    "WP\$",
    "WRB",
    "``"
]
const UposDict = Dict{String,UInt8}() 
for (i, v) in enumerate(UposVals)
    UposDict[v] = i
end

const DepRelVals = [ # 50 vals
    "ROOT",
    "abbrev",
    "acomp",
    "advcl",
    "advmod",
    "amod",
    "appos",
    "attr",
    "aux",
    "auxpass",
    "cc",
    "ccomp",
    "complm",
    "conj",
    "cop",
    "csubj",
    "csubjpass",
    "dep",
    "det",
    "dobj",
    "expl",
    "infmod",
    "iobj",
    "mark",
    "measure",
    "neg",
    "nn",
    "nsubj",
    "nsubjpass",
    "null",
    "num",
    "number",
    "parataxis",
    "partmod",
    "pcomp",
    "pobj",
    "poss",
    "possessive",
    "preconj",
    "pred",
    "predet",
    "prep",
    "prt",
    "punct",
    "purpcl",
    "quantmod",
    "rcmod",
    "rel",
    "tmod",
    "xcomp"
]

const DepRelDict = Dict{String,UInt8}() 
for (i, v) in enumerate(DepRelVals)
    DepRelDict[v] = i
end