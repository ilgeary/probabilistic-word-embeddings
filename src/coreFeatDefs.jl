# Feature definitions

include("initModel.jl")

#include("initModel_v-1.0.jl")
#include("fvalListsAndDicts.jl")

struct ModelFeature 
    context::Vector{Tuple{Vararg{Function}}}
    f::Tuple{Vararg{Function}} 
    val::Vector{T} where T<: Any
    metric::Vector{TT} where TT<: Any #usually counts
    index::Vector{Vector{UInt}}  #UInt8??
end

upos(stok) = stok.upos
entity(stok) = stok.entity
caps(stok) = stok.caps
depRel(stok) = stok.depRel
headOffset(stok) = stok.headOffset
headDir(stok) = sign(stok.headOffset)
basePOS(stok) = basePosDict[stok.upos]
form(stok) = formLemmaCodeToId(stok.formLemma0, stok.formLemma, :form)
lemma(stok) = formLemmaCodeToId(stok.formLemma0, stok.formLemma, :lemma)
#personPOS(u)
#tensePOS(u)
cdForm(stok) = stok.upos == "CD" ? replace(stok.form, r"\d" => s"8") : nothing

rightSibling(dToks, i) = treeSibling(d, i, 1)
leftSibling(dToks, i) = treeSibling(d, i, -1)
innerSibling(dToks, i) = treeSibling(d, i, sign(d.toks[i].headOffset))
outerSibling(dToks, i) = treeSibling(d, i, -1 * sign(d.toks[i].headOffset))
leftNeighbor(dToks, i) = i - 1
rightNeighbor(dToks, i) = i + 1
head(dToks, i) = i + d[i].headoffset

function treeChildren(d, i=1)
    i <= 0 && return
    for tok in Iterators.rest(d.utoks, i)
        tok.headOffset == 0 && continue
        tok.headOffset > 0 && push!(d.leftChildren[i+ tok.headOffset], i)
        push!(d.rightChildren[i+ tok.headOffset], i)
    end
end

function treeSibling(d, i, dir)
    tok.headOffset == 0 && return 0
    sideChildren =  tok.headOffset < 0 ? 
        d.rightChildren[i + d.toks[i].headOffset] :
        d.leftChildren[i + d.toks[i].headOffset] 
    j = findfirst(x->x=i, sideChildren) + dir
    j < 1 || j > length(sideChildren) && return 0
    return j
end


function checkbit(s::Vector{UInt8}, n)
    n > length(s) * 8 && return false
    j = Int(ceil(n / 8))
    k = (n - 8(j-1))
    #println("j:",j, " k:", k, " s[j]:", bitstring(s[j]), " >>:", bitstring(s[j] >> (k-1)))
    (s[j] >> (k-1)) & UInt8(1) != 0
end

# Determine the pattern of uppercase-ness for str.  
# type values must correspond exactly with capsVals list.
function capsType(str)
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
    #extraBytes = UInt8[]
    t = if (uc == 0)                                     "none"        
    elseif (uc == 1     && checkbit(custom, 1) == 1)     "1st"
    elseif (uc == 1     && checkbit(custom, 2) == 1)     "2nd"
    elseif (uc == 1     && checkbit(custom, 3) == 1)     "3rd"
    elseif (uc == uc_+1 && checkbit(custom, 1) == 1)     "title" 
    elseif (uc == uc_)                                   "camel"
    elseif (uc >= 1 && lc == 0)                          "all"
    elseif (uc >= 1 && lc == 1 && islowercase(str[end])) "allButLast"
    else                                                 "custom"
    #else   extraBytes = map(htol, custom);               "custom:" * string(length(custom))
    end            #htol (host-to-littleEndian) to maintain functionality across Mac vs Windows, etc.
    return t  #, Tuple{Vararg{UInt8}}(extraBytes)
end

function catStrTransform(valStr::String, valClass::Symbol)
    return spec.catStrTransforms[valClass][1][valStr]
end

function catStrTransform(valId, valClass::Symbol)::String
    return spec.catStrTransforms[valClass][2][valId]
end

function globalVocabTransform(valStr::String, valClass::Symbol)
    return globalVocabCode(valStr)
end

function globalVocabTransform(valId, valClass::Symbol)
    return vocabCodeToStr(valId[1], valId[2])
end

function formLemmaPairToStr(flpair)
    #println("flpair:", flpair.form0, " ", flpair.form, " ", flpair.lemma0, " ", flpair.lemma)
    return vocabCodeToStr(flpair.form0, flpair.form) * " " * vocabCodeToStr(flpair.lemma0, flpair.lemma)
end

#struct ModelStats
#    vocabListLength

function vocabCodeToStr(v0, v)
    vId = codeToId(v0, v) 
    #println("vocabCodeToStr:", vId)
    #println(spec.vals[:vocabListLength])
    tmp = vId - spec.vals[:vocabListLength]
    vId == 0 ? "<null>" :
        vId <=  spec.vals[:vocabListLength] ? spec.vocabList[vId] :
        formLemmaPairToStr(spec.lemmaList[vId - spec.vals[:vocabListLength]])
end

# Map vocab code (section + entry number) to list id
function codeToId(code0, code)
    #println("codeToId:", code0, " ", code)
    code0>0 ? (code0-1)*(1+typemax(UInt16)) + code + 1 : 0
end

function globalVocabCode(str)
    #println("Here146", spec.vals)
    imax = spec.vals[:vocabDictVecLength]
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

function findFormLemmaInList(formLemma)
    i = searchsortedfirst(spec.lemmaList, formLemma)
    len = spec.vals[:lemmaListLength] 
    i <= len && formLemma == spec.lemmaList[i] && return i
    i > 1 && formLemma.form0 == spec.lemmaList[i-1].form0 && formLemma.form == spec.lemmaList[i-1].form && return i-1
    i+1 <= len && formLemma.form0 == spec.lemmaList[i+1].form0 && formLemma.form == spec.lemmaList[i+1].form && return i-1
    return 0
end

# map list index into (sectionID, entryID) pair used for disk encoding of training data
function codifyFormLemmaId(i)
    i == 0 && return 0, 0
    j = i + spec.vals[:vocabListLength]  ## double-check this
    id0, id = divrem(j, (typemax(UInt16) +1))
    return UInt8(id0+1), UInt16(id)
end

# Get code used for encoding form + lemma in depCC data
function getFormLemmaCode(form0, form, lemma0, lemma)
    if form0 == lemma0 && form == lemma
        return form0, form
    else codifyFormLemmaId(findFormLemmaInList(FormLemmaPair(form0, lemma0, form, lemma)))
    end
end

formLemmaCodeToInt(code0, code) = (code0 - 1) * (typemax(UInt16) +1) + code

function formLemmaCodeToId(code0, code, field)
    code0 == 0 && return 0
    len = length(spec.vocabDictVec)
    lId = formLemmaCodeToInt(code0, code)
    len = length(spec.vocabList)
    lId <= len && return lId
    formLemma = spec.lemmaList[lId - len]
    return formLemmaCodeToInt(getfield(formLemma, field)...)
end

function writePretty(f, x::UdepTokenCore)
    tr = spec.catStrTransforms
    write(f, "upos:",    x.upos>0   ? tr[:upos][2][x.upos] : "<null>", 
             " entity:", x.entity>0 ? tr[:entity][2][x.entity] : "<null>", 
             " caps:",   x.caps>0   ? tr[:caps][2][x.caps] : "<null>",
             " depRel:", x.depRel>0 ? tr[:depRel][2][x.depRel] : "<null>",
             " headOffset:", x.headOffset != typemax(UInt8) ? string(x.headOffset) : "<null>",
             " formLemma:", vocabCodeToStr(x.formLemma0, x.formLemma))
end


#=
function treeOffset(dToks, i)
    hOffset = dToks[i].headOffset
    if hOffset == 0
        return 0
    else
        s = sign(hOffset)
        headId = i + hOffset
        o=0
        for j in i+s : s : i + hOffset - s
            j + dToks[j].headOffset == headId && (o += 1)
        end
        return o*sign
    end
end 

function rightSibling(dToks, i)
    hOffset = dToks[i].headOffset
    if hOffset == 0
        return 0
    else
        s = 1 #sign(hOffset)
        #headId = i + hOffset
        #o=0
        for j in i+s : s : i + hOffset - s
            j + dToks[j].headOffset == headId && (o += 1)
        end
        return o*sign
    end
end
=#

