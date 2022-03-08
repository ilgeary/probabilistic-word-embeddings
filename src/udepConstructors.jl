# Utilities for constructing UDep token structures from original tsv data

include("extractWiktionaryVocab.jl")

# map a line in CoNLL-U Format to UdepTokenCoreStrings struct
function conlluLineToUdepCoreStrings(line, rootID)
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
