# Learn Word Embeddings from big data source such as https://arxiv.org/pdf/1710.01779.pdf
# To start Julia with x number of threads: julia -t x

using Unicode
#using Mmap
#using Debugger
include("UDepUtils.jl") 

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

# loadTierInfo AFTER setup has run
function loadTierInfo(tierNum, spec)
    tierDict = spec.tierDict
    tierList = spec.tierList
    open(tierKeyFile(spec)) do f
        for (x, line) in enumerate(readline(f))
            m = match(r"^(.*)\t\d+$", line)
            key = m[1]
            tierDict[key] = x
            push!(tierList, key)
        end
    end
end