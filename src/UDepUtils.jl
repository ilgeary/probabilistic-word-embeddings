# Utilities for dealing with UDep data

using Unicode, BenchmarkTools
# using StructIO

struct UdepTokenBase 
    upos::UInt8
    entity::UInt8
    caseType::UInt8
    depRel::UInt8
    headOffset::Int8
    formLemma0::UInt8   # section id
    formLemma::UInt16   # id within section
end

struct UdepToken
    base::UdepTokenBase
    formStr::String
    customCase::Tuple{Vararg{UInt8}}
end

const nullUtok = UdepToken(
    UdepTokenBase(0, 0, 0, 0, typemax(Int8), 0, 0),
    "", 
    ()
)

function formId(form0, form)
    form0>0 ? (form0-1)*(typemax(UInt16)+1) + form : 0
end

function writePretty(f, x::UdepTokenBase, vocabList) #, vocabDictVec)
    fId = formId(x.form0, x.form) 
    v = fId > 0 ? vocabList[fId] : "<null>"
    #println("writePretty:", x.form0, " ", x.form, " v:", v, " globalId: ", map(Int, globalVocabId(vocabDictVec, v)))
    write(f, "upos:", x.upos>0 ? UposVals[x.upos] : "<null>", 
             " entity:", x.entity>0 ? EntityVals[x.entity] : "<null>", 
             " caseType:", x.caseType>0 ? CasetypeVals[x.caseType] : "<null>",
             " depRel:", x.depRel>0 ? DepRelVals[x.depRel] : "<null>",
             " headOffset:", string(x.headOffset),
             " form:", v)
end

struct VocabSection   # used by ModelSpec's vocabDictVec
    key::String
    dict::Dict{String, UInt16}
end

struct BinFormLemma
    form0::UInt8  # form section
    lemma0::UInt8 # lemma section
    form::UInt16  # form ID
    lemma::UInt16  # lemma ID
end

import Base.isless
function isless(x1::BinFormLemma, x2::BinFormLemma) 
    x1.form0 < x2.form0 || 
    (x1.form0 == x2.form0 && 
        (x1.form < x2.form ||
        (x1.form == x2.form && 
            (x1.lemma0 < x2.lemma0 ||
            (x1.lemma0 == x2.lemma0 && x1.lemma < x2.lemma)))))
end

struct ModelSpec
    delimChar::Char     # typically tab for natural language data
    beginDocTok::UdepTokenBase # symbol used to mark the start of a new doc and sentence
    beginSenTok::UdepTokenBase # symbol used to mark the start of a new sentence
    awsRegion::String   # region of s3 bucket containing input data from wiktionary and single depcc chunk used for setting up tiers
    s3bucket::String    # name of bucket containing input data used to setup binarization
    tierSource::String  # name of single depcc chunk used to setup feature combo tiers
    vocabSource::String # name of vocab source file, eg. derived from wikitionary
    tierFile::String    # name of output file that stores list of tiers
    vocabFile::String   # name of output file that stores global form+lemma vocab entries
    specFile::String    # name of output file that stores bindings for this ModelSpec
    numTiers::UInt8     # number of feature combo sets organized by frequency, with fewer bytes associated with lower tiers
    tierThreshold::UInt # frequency level used as threshold between tiers
    tierIndices::Vector{UInt8}            # vector with numTiers entries ranging from 2-256 indicating the starting indices of each tier
    tierDict::Dict{UdepTokenBase, UInt8}  # maps feature combo to tier number for high frequency feature combos
    tierList::Vector{UdepTokenBase}       # ordinal list of tiered feature combos
    vocabDictVec::Vector{VocabSection}    # map token strings of global vocab to integers
    vocabList::Vector{String}             # ordinal list of global vocab
    lemmaList::Vector{BinFormLemma}       # part-of-speech-based lemma
end

# TIERS
function Tier_1_Key(tok::UdepTokenBase)
    UdepTokenBase(tok.upos, tok.entity, tok.caseType, tok.depRel, tok.headOffset, tok.form0, tok.form)
end
function Tier_2_Key(tok::UdepTokenBase)
    UdepTokenBase(tok.upos, tok.entity, tok.caseType, tok.depRel, tok.headOffset, 0, 0)
end
function Tier_3_Key(tok::UdepTokenBase)
    UdepTokenBase(tok.upos, tok.entity, tok.caseType, tok.depRel, typemax(Int8), 0, 0)
end
function Tier_4_Key(tok::UdepTokenBase)
    UdepTokenBase(tok.upos, tok.entity, tok.caseType, 0, typemax(Int8), 0, 0)
end
function Tier_5_Key(tok::UdepTokenBase)
    UdepTokenBase(tok.upos, 0, 0, 0, typemax(Int8), 0, 0)
end

const tierKeyFs = [Tier_1_Key, Tier_2_Key, Tier_3_Key, Tier_4_Key, Tier_5_Key]  # tierKeyFs

#=function Tier_2_Tuple(tok::UdepTokenBase, delimChar)
    l = length(tok.upos)
    if l >1 && SubString(tok.upos, 1, 2) in  ["CD", "JJ", "NN", "RB", "VB"]
        join([tok.upos, tok.entity, tok.caseType, tok.depRel, tok.headOffset], delimChar)
    else
        join([tok.form, tok.lemma, tok.upos, tok.entity, tok.caseType, tok.depRel], delimChar)
    end
end  =#

function getTierKeyId(tierDict, tok, maxTierNum)
    #maxTierNum>0 && println("getTierKeyId:", maxTierNum, " ", tok )
    for x in 1:maxTierNum
        #println("u110:", tok, " ", x)
        key = tierKeyFs[x](tok) #Eg: Tier_1_Tuple(tok)
        id = get(tierDict, key, 0)
        #println("u115 id:", id, " key:", key, " tier:", x)
        if (id > 0) return id, key, x end
    end
    return 0, nullUtok, 0
end

function globalVocabId(str)
    imax = length(spec.vocabDictVec)
    i0 = max(1, Int(trunc((Int(str[1]) - Int('a') +1)/(26/imax))))
    i = min(i0, imax)
    #str == "ministers" && println("0:", str, " imax:", imax, " i0:", i0, " i:", i, "dict key:", vocabDictVec[i].key)
    while i > 1 && str < spec.vocabDictVec[i].key
        i -= 1
    end
    #str == "ministers" && println("1:", str, i, " dict key:", vocabDictVec[i].key, " dict key+1:", i<imax && vocabDictVec[i+1].key)
    while i < imax && str >= spec.vocabDictVec[i+1].key
        i += 1
    end
    v = get(spec.vocabDictVec[i].dict, str, 0)
    #str == "ministers" && println("2:", str, i, "dict key:", vocabDictVec[i].key, " v:", v)
    v > 0 && return i, v
    return 0, 0
end

function globalFormLemmaId(formStr, lemmaStr)
    if formStr == lemmaStr
        globalVocabId(formStr)
    else 
        i = searchsortedfirst(spec.lemmaList, lemmaStr) + length(spec.vocabList)
    end
end

# map a line in CoNLL-U Format to UdepToken struct
function conlluLineToUdep(delimChar, vocabDictVec, line, rootID)
    #tierNum> 1 && println("line2dep142:", line, " rootID:", rootID)
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
    form = lowercase(cols[2]) #lowercase(cols[3]))
    lemma = lowercase(cols[3])
    #fl.form == "ministers" && println("line2dep:", fl, " ", line)
    i, v = globalFormLemmaId(vocabDictVec, form, lemma)
    #tierNum> 1 && println("line2dep158:", i, " ", v, " rootID:", rootID)
    return UdepToken(
        UdepTokenBase(
            UposDict[cols[4]],          # upos           45 values
            EntityDict[cols[10]],       # entityType      7 values
            CasetypeDict[caseT],        # caseType       15 values
            DepRelDict[depRel],         # depRel         50 values
            headOffset,                 # headOffset    256 values (+/- 128)
            i,                          # vocab section ~17 values
            v),                         # vocab ID    65536 values
        form, customCase),        # customCase is the bit pattern for custom capitalization: 0-7 bytes
    rootID
end

# map a line in CoNLL-U Format to UdepToken struct
function conlluLineToUdepF(delimChar, vocabDictVec)
    (line, rootID) -> conlluLineToUdep(delimChar, vocabDictVec, line, rootID)
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
    str != "" && !occursin(r"\s", str) && isascii(str)
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

const entityVals = [ # 7 vals
    "B-Location",
    "B-Organization",
    "B-Person",
    "I-Location",
    "I-Organization",
    "I-Person",
    "O"
]

const entityDict= Dict{String,UInt8}() 
for (i, v) in enumerate(entityVals)
    entityDict[v] = i
end

const casetypeVals = [ # 15 vals
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

const casetypeDict= Dict{String,UInt8}() 
for (i, v) in enumerate(casetypeVals)
    casetypeDict[v] = i
end

const uposVals = [ # 45 vals plus two boundary markers
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
const uposDict = Dict{String,UInt8}() 
for (i, v) in enumerate(uposVals)
    uposDict[v] = i
end

# Maps a UposDict integer to a BasePos integer, in which nouns, verbs, adjectives and adverbs are lumped together in four groups
const basePosDict = Dict{UInt8,UInt8}() 
for (i, v) in enumerate(uposVals)
    startswith(v, "J") ? basePosDict[i] = uposDict["JJ"] :
    startswith(v, "N") || startswith(v, "CD") ? basePosDict[i] = uposDict["NN"] :
    startswith(v, "RB") ? basePosDict[i] = uposDict["RB"] :
    startswith(v, "V") ? basePosDict[i] = uposDict["VB"] :
    basePosDict[i] = i
end

const agreementNumberNone       = 0
const agreementNumberSingular   = 1
const agreementNumberPlural     = 2
const agreementNumberAmbiguous  = 3

# Agreement between verbs and nouns
const agreementNumberDict = Dict{UInt8,UInt8}() 
for (i, v) in enumerate(uposVals)
    v in ("CD") ? agreementNumberDict[i]            = agreementNumberAmbiguous :  # ambiguous, eg: "one" vs. "two"
    v in ("NN", "NNP") ? agreementNumberDict[i]     = agreementNumberSingular :   # singular
    v in ("NNPS", "NNS") ? agreementNumberDict[i]   = agreementNumberPlural :     # plural
    v in ("VBP") ? agreementNumberDict[i]           = agreementNumberPlural :     # plural
    v in ("VBZ") ? agreementNumberDict[i]           = agreementNumberSingular :   # singular
    agreementNumberDict[i]                          = agreementNumberNone         # irrelevant
end

const singularCDstrs = ("one", "1", "1.0", "1.00")
const singularCDs = map(x->globalVocabId(vocabDictVec, x), singularCDstrs)

const depRelVals = [ # 50 vals
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

const depRelDict = Dict{String,UInt8}() 
for (i, v) in enumerate(depRelVals)
    depRelDict[v] = i
end