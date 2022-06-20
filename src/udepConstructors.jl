# Utilities for constructing UDep token structures from original tsv data

include("extractWiktionaryVocab.jl")

const beginDocStr = "<beginDoc>"
const beginSenStr = "<beginSen>"
const nullTreeOffset = typemax(Int8)
const nullUtokStrings    = UdepTokenCoreStrings("", "", "", "", nullTreeOffset, "", "")  
const beginDocTokStrings = UdepTokenCoreStrings(beginDocStr, "", "", "", nullTreeOffset, "", "")
const beginSenTokStrings = UdepTokenCoreStrings(beginSenStr, "", "", "", nullTreeOffset, "", "")
const nullUtok = UdepTokenCore(0, 0, 0, 0, nullTreeOffset, 0, 0)  
const beginDocTok = UdepTokenCore(; upos = spec.catStrTransforms[:upos][beginDocStr]) # symbol used to mark the start of a new doc and sentence
const beginSenTok = UdepTokenCore(; upos = spec.catStrTransforms[:upos][beginSenStr]) # symbol used to mark the start of a new sentence

# map a line in CoNLL-U Format to UdepTokenCoreStrings struct
function conlluLineToUdepCoreStrings(line, rootID)
    length(line)<=0 && return nullUtokStrings, 0 
    startswith(line, "# newdoc") && return beginDocTokStrings, 0
    startswith(line, "# sent_id") && return beginSenTokStrings, 0
    startswith(line, "#") && return nullUtokStrings, 0
    cols = split(chomp(line), spec.delimChar)
    rawtok = cols[2]
    id = tryparse(UInt8, cols[1])
    id === nothing && error("Error: id===nothing:" * line)
    hid = tryparse(UInt8, cols[7])
    hid === nothing && error("Error: hid===nothing:" * line)
    depRel = cols[8]
    id == 0 && (rootID = -1)
    depRel == "ROOT" && (rootID = id)
    headOffset = if (depRel == "punct" && hid == rootID) 0 else Int8(hid) - Int8(id) end
    return UdepTokenCoreStrings(
        cols[4],             # upos           45 values
        cols[10],            # entityType      7 values, 4 bits; 
        capsType(rawtok),    # capsT           9 values
        depRel,              # depRel         50 values
        headOffset,          # headOffset    256 values (+/- 128)
        lowercase(rawtok),   # form
        lowercase(cols[3])), # lemma
    rootID
end

# map a line in CoNLL-U Format to UdepToken struct
function conlluLineToUdepCore(line, rootID)  
    #tierNum> 1 && println("line2dep142:", line, " rootID:", rootID)
    u, rootID = conlluLineToUdepCoreStrings(line, rootID) 
    u == nullUtokStrings && return nullUtok, 0
    u == beginDocTokStrings && return beginDocTok, 0
    u == beginSenTokStrings && return beginSenTok, 0 
    form0, form = globalVocabCode(u.form) 
    lemma0, lemma = globalVocabCode(u.lemma)
    v0, v = getFormLemmaCode(form0, form, lemma0, lemma)
    #entity_caps = UInt8(entityDict[cols[10]]) << 4 & UInt8(capsValDict[caps])
    tr = spec.catStrTransforms
    #return UdepToken(
        return UdepTokenCore(
            tr[:upos][1][u.upos],       # upos           45 values
            tr[:entity][1][u.entity],   # entityType      7 values, 4 bits; 
            tr[:caps][1][u.caps],       # capsT           9 values
            tr[:depRel][1][u.depRel],   # depRel         50 values
            u.headOffset,               # headOffset    256 values (+/- 128)
            v0,                         # vocab section ~17 values
            v),                         # vocab ID    65536 values
        #formStr, lemmaStr, customCaps),        # customCaps is the bit pattern for custom capitalization: 0-7 bytes
    rootID
end
