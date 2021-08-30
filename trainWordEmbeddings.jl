# Learn Word Embeddings from big data source such as https://arxiv.org/pdf/1710.01779.pdf
# To start Julia with x number of threads: julia -t x

#using Mmap
#using Debugger

using Unicode
using JLD2
const delimChar = '\t'

function binarizeDepccFile()
    vocabDict     = Dict{String, UInt32}()
    sizehint!(vocabDict, 300000)

    featDict       = Dict{String, UInt16}()
    sizehint!(featDict, 7000)

    filePrefix = "/Users/irenelangkilde-geary/Projects/UDepParse/"
    #filePrefix = "/home/irene/"
    bindata = Vector{Tuple{UInt8,UInt8,UInt16,UInt32,UInt32}}()
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
                            if id !== nothing
                                h = tryparse(UInt8, cols[7])
                                hId = if (h === nothing) UInt8(0) else h end
                                caseT = caseType(cols[2])
                                v = if (caseT == "customUp") cols[2] else lowercase(cols[2]) end
                                # lump together: word form, lemma, upos, misc (entity type); 
                                # roughly 376048 uniq combos per chunk, so need 18 bits 
                                vv = v * delimChar * lowercase(cols[3]) * delimChar * cols[4] * delimChar * cols[10]
                                vvId = UInt32(get!(vocabDict, vv, length(vocabDict)+1))
                                #  3 bits for caseT, 6 bits for deprel (~50 uniq), 8 bits for head offset
                                featsId = UInt16(get!(featDict, caseT * ":" * cols[4] * ":" * cols[8] * ":" * cols[10], length(featDict)+1))
                                println(sizeof(id), " ", sizeof(hId), " ", sizeof(featsId), " ", sizeof(vId), " ",sizeof(vId0))
                                push!(bindata, (id, hId, featsId, vId, vId0))   #  cols[1:4], cols[7:8], cols[10]))
                            end
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
    #elseif (length(t)>=3 && t[3] =='Q' && uc == 1)  "3rdAndOnlyUp"
    elseif (t[1] =='Q' && uc_ == uc-1)              "title"  #titlecase
    elseif (uc_ == uc)                              "camel"
    elseif (lc == 0)                                "all"
    elseif (uc>=1 && lc==1 && t[length(t)] == 'q')  "allPlural"
    else                                            "custom"
    end
end

#@enter 
binarizeDepccFile()

#=
    s = open("/data/depccEmbeddings.bin", "w+")
# We'll write the dimensions of the array as the first two Ints in the file
write(s, size(A,1))
write(s, size(A,2))
# Now write the data
write(s, A)
close(s)
=#