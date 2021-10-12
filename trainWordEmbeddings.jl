# Learn Word Embeddings from big data source such as https://arxiv.org/pdf/1710.01779.pdf
# To start Julia with x number of threads: julia -t x

#using Mmap
#using Debugger

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

struct Tier
    size    #Int
    list    #Vector{String}
    dict    #Dict{Int}
    keyF    #UDepToKey
end

struct ModelSpec
    delimChar::Char
    mainPath::String
    datPath::String
    modelPath::String
    tierSource::String
    tierSizes::Vector{UInt8}
    tierKeyFs::Vector{Function}
    tierList::Vector{String}
    tierDict::Dict{String,UInt8}
end

function InitModelSpec()::ModelSpec
    delimChar = '\t'
    tier1size = 64   # must be <= typemax(UInt8) - 2
    tier2size = 128  # must be <= typemax(UInt8) - 2 - tier1size
    spec =  ModelSpec(delimChar,
        "/Users/irenelangkilde-geary/Projects/UDepParse/",  #mainPath
        "origDepcc/",                                       #datPath
        "model/",                                           #modelPath
        "part-m-00009", #"part-m-19038"                     #tierSource
        [tier1size, tier2size, typemax(UInt8) - 2 - tier1size - tier2size],                     #tierSizes
        [function(x) f(x, delimChar) end for f in [Tier_1_Tuple, Tier_2_Tuple, Tier_3_Tuple]],  #tierKeyFs
        let tmp = ["<beginDoc>", "<beginSen>"]; sizehint!(tmp, typemax(UInt8)); tmp end, #tierList
        let tmp = Dict{String,UInt8}(); sizehint!(tmp, typemax(UInt8)); tmp end          #tierDict
    )
    return spec
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
    tok.upos
end

function prepBinaryScheme()
    spec = InitModelSpec()
    for x in 1:length(spec.tierSizes)
        println("Setting up tier ", x)
        setupTier(x, spec)
    end
    return spec
end

function setupTier(tierNum, spec) 
    tupleCounts = collectCounts(tierNum, spec)
    writeTierInfo(tierNum, tupleCounts, spec)
end

function collectCounts(tierNum, spec)
    tupleCounts = Dict{String,Int}()
    sizehint!(tupleCounts, 43828335)
    open(spec.mainPath * spec.datPath * spec.tierSource) do f
        rootID = -1
        for line in eachline(f)
            (length(line)<=0 || line[1] == '#') && continue   #### refine this later
            tok, rootID = conlluLineToUdep(line, rootID)
            found =false
            for x in 1:tierNum-1
                entry = spec.tierKeyFs[x](tok) #Eg: Tier_1_Tuple(tok)
                tierDict = spec.tierDict
                if (haskey(tierDict, entry)) 
                    found = true
                    break
                end
            end
            if !found
                entry = spec.tierKeyFs[tierNum](tok)
                (tupleCounts[entry] = get(tupleCounts, entry, 0) + 1)
            end
        end
    end 
    return tupleCounts
end

function tierKeyFile(tierNum, spec)
    return spec.mainPath * spec.modelPath * "tier" * string(tierNum) * "dict.tsv"
end

function writeTierInfo(tierNum, tupleCounts, spec)
    sortedCounts = sort(collect(tupleCounts), rev=true, by=x->getindex(x,2))
    tierDict = spec.tierDict
    tierList = spec.tierList
    open(tierKeyFile(tierNum, spec), "w") do f
        for (i,x) in enumerate(sortedCounts)
            i > spec.tierSizes[tierNum] && break
            tierDict[x[1]] = i
            push!(tierList, x[1])
            println(x[1], spec.delimChar, string(Int(x[2])))
            write(f, x[1] * "\n")
        end
    end
end

# loadTierInfo AFTER setup has run
function loadTierInfo(tierNum, spec)
    tierDict = spec.tierDict
    open(tierKeyFile(tierNum, spec)) do f
        for (x, line) in enumerate(readline(f))
            tierDict[chomp(line)] = x
        end
    end
end

function binarizeDepccFile()
    vocabList = Vector{String}
    vocabDict = Dict{String, UInt32}()
    sizehint!(vocabDict, 300000)

    featDict = Dict{String, UInt16}()
    sizehint!(featDict, 7000)
    bindata = Vector{Tuple{UInt8,UInt8,UInt16,UInt32,UInt32}}()

    filePrefix = "/Users/irenelangkilde-geary/Projects/UDepParse/"
    #filePrefix = "/home/irene/"
    open(filePrefix * "conll.paths") do f0
        for fl in eachline(f0)
            fnTail = SubString(fl, findlast('/', fl)+1, length(fl)-3)
            fn = filePrefix * "origDepcc/" * fnTail
            if isfile(fn)
                open(fn) do f1
                    for f1l in eachline(f1)
                        if length(f1l)>0 && f1l[1] != '#'        #### refine this later
                            cols = split(f1l, "\t")
                            id = tryparse(UInt8, cols[1])
                            id === nothing && continue
                            h = tryparse(UInt8, cols[7])
                            hId = if (h === nothing) UInt8(0) else h end
                            capsT = capsType(cols[2])
                            v = if (capsT == "custom") cols[2] else lowercase(cols[2]) end
                            # lump together: word form, lemma, upos, misc (entity type); 
                            # roughly 376048 uniq combos per chunk, so need 18 bits 
                            vv = v * delimChar * lowercase(cols[3]) * delimChar * cols[4] * delimChar * cols[10]
                            vvId = UInt32(get!(vocabDict, vv, length(vocabDict)+1))
                            #  3 bits for capsT, 6 bits for deprel (~50 uniq), 8 (7?) bits for head offset
                            featsId = UInt16(get!(featDict, capsT * ":" * cols[4] * ":" * cols[8] * ":" * cols[10], length(featDict)+1))
                            println(sizeof(id), " ", sizeof(hId), " ", sizeof(featsId), " ", sizeof(vId), " ",sizeof(vId0))
                            push!(bindata, (id, hId, featsId, vId, vId0))   #  cols[1:4], cols[7:8], cols[10]))
                        end
                    end
                end
            end
        end
    end
    save_object(filePrefix * "bindata.jld2", bindata)
    println("Done saving bindata.jdl2")
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

#@enter 
#binarizeDepccFile()
prepBinaryScheme()





#=
function compareTier1Schemas()
    tupleCounts = Dict{String, UInt32}()
    sizehint!(tupleCounts, 43828335)
    tier1dict = Dict{String, UInt8}()
    open(fprefix * "tier1dict.tsv") do f
        for (x, line) in enumerate(eachline(f))
            tier1dict[chomp(line)] = x
            x>=typemax(UInt8) && break
        end
    end
    open(fprefix * "tier1dictB.tsv") do f
        for (x, line0) in enumerate(eachline(f))
            line = chomp(line0)
            if !haskey(tier1dict, line)
                println(string(x) * ":" * line)
            end
        end
    end
end

function setupTier(num, fileName) 
    tupleCounts = Dict{String, UInt32}()
    sizehint!(tupleCounts, 43828335)
    open(fileName) do f
        rootID = -1
        for line in eachline(f)
            (length(line)<=0 || line[1] == '#') && continue   #### refine this later
            tok, rootID = conlluLineToUdep(line, rootID)
            entry = Tier_1_Tuple(tok)
            tupleCounts[entry] = get(tupleCounts, entry, 0) + 1
        end
    end
    tier1 = sort(collect(tupleCounts), rev=true, by=x->getindex(x,2))
    open(fprefix * "tier1dict.tsv", "w") do f
        for (i,x) in enumerate(tier1)
            i > tier1Size && break
            println(x[1], delimChar, string(Int(x[2])))
            write(f, x[1] * "\n")
        end
    end
end

=#

