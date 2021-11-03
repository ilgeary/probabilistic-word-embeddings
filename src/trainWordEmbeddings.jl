# Learn Word Embeddings from big data source such as https://arxiv.org/pdf/1710.01779.pdf
# To start Julia with x number of threads: julia -t x

using Unicode
using BSON

#using Mmap
#using Debugger

include("UDepUtils.jl") 

function binarizeDepccFile()
    #vocabList = Vector{String}
    #vocabDict = Dict{String, UInt16}()
    #sizehint!(vocabDict, 300000)

    #featDict = Dict{String, UInt16}()
    #sizehint!(featDict, 7000)
    #bindata = Vector{Tuple{UInt8,UInt8,UInt16,UInt32,UInt32}}()
    spec = BSON.load(mainPath * "modelSpec.bson", @__MODULE__)[:a]
    open(spec.datPath * "conll.paths") do f0
        for fl in eachline(f0)
            fnTail = SubString(fl, findlast('/', fl)+1, length(fl)-3)
            fn = spec.datPath * fnTail
            !isfile(fn) && continue
            open(fn) do f1
                
                end
            end
        end
    end
    #save_object(filePrefix * "bindata.jld2", bindata)
    println("Done") # saving bindata.jdl2")
end

function processDoc(h)
    rootID = -1

    vocabDict = Dict{String, UInt16}()
    sizehint!(vocabDict, 5000)

    docToks = Vector{UdepToken}
    sizehint!(docToks, 5000)

    docCodes = Vector{UInt8}
    sizehint!(docCodes, 5000)

    docTiers = Vector{UInt8}
    sizehint!(docTiers, 5000)

    for (i, fLine) in enumerate(eachline(h))
        length(fLine)<=0 && continue
        i>5000 && break
        if fLine[1] == '#'
            (nextind(fLine,7)!=8 || fLine[1:8] != "# newdoc") && continue
            writeDoc()  
            empty!(vocabDict)         
            empty!(docToks)         
            empty!(docCodes)         
            empty!(docTiers)         
        else
            tok, rootID = conlluLineToUdep(fLine, rootID)
            push!(docToks, tok)
            key, tier = encodeToken(tok, spec)
            push!(docCodes, key)
            push!(docTiers, tier)
            id = vocabDict[tok.form]
            docDict[id] = get(docDict, id, 0) + 1
            eDict[e] = get(eDict, e, 0) + 1
            #println("Encoding: ", , "\t", tok.form)
            #push!(bindata, (id, hId, featsId, vId, vId0))   #  cols[1:4], cols[7:8], cols[10]))
        end
    end
end

function writeDoc()
    sortedCounts = sort(collect(vocabDict), rev=true, by=x->getindex(x,2))
    oneCounts = 0
    for (w,c) in sortedCounts
        c==1 && (oneCounts +=1)
    end
    println("len sortedCounts: ", length(sortedCounts), " i:", i, "onesies:", oneCounts, ", ", oneCounts/i)
    println("sortedCounts: ", sortedCounts)
    println("eDict:", eDict)
end

function encodeToken(tok, spec)
    tierKeyFs = getTierKeyFs(spec.delimChar)
    key = 0
    tier=0
    for x in 1:spec.numTiers
        key = tierKeyFs[x](tok) #Eg: Tier_1_Tuple(tok)
        key = get(spec.tierDict, key, 0)
        if key > 0 
            tier=x
            break
        end
    end
    key <= 0 && (key = typemax(UInt8))
    return key, tier
end

binarizeDepccFile()

#= loadTierInfo AFTER setup has run
function loadFeatTierInfo(tierNum, spec)
    spec = BSON.load(mainPath * spec.specFile, @__MODULE__)
    tierDict = spec.tierDict
    tierList = spec.tierList
    open(mainPath * "enwiki-20190320-words-frequency.txt") do f
        for (i, line) in enumerate(readline(f))
            m = match(r"^(.*)\s+\d+$", line)
            key = m[1]
            tierDict[key] = x
            push!(tierList, key)
        end
    end
end
=#