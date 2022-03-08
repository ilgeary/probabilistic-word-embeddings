# setupDepccVals.jl

include("coreFeatDefs.jl")

function collectFeatureInfoFromDepcc()
    loadFeatSpec()
    counts = Dict{Symbol, Dict{String, UInt32}}()
    sizehint!(counts, 200)
    depccFeats = Symbol[]
    for f in spec.featspecs
        if f.valSource == :depcc 
            push!(depccFeats, f.name)
            counts[f.name] = Dict()
        end
    end
    println("depccFeats:", depccFeats)
    rootId = -1
    for line in eachline(spec.tierSource)
        (length(line)<=0 || line[1] == '#') && continue 
        u, rootId = conlluLineToUdepCoreStrings(line, rootId)
        for g in depccFeats
            gv = eval(g)(u)
            #wf = lowercase(cols[2])  #, lowercase(cols[3]))
            gv !== nothing && (counts[g][gv] = get(counts[g], gv, 0) + 1)
        end
    end
    println("Counts collected for:", keys(counts))
    filterCoreCatFeatVals(counts)
end 

function filterCoreCatFeatVals(counts)
    for (feat, fcounts) in pairs(counts)
        fs = Symbol(feat)
        filterC = spec.featspecDict[fs].filter
        valList = Vector{String}()
        for (v,c) in pairs(fcounts)
            c>filterC && push!(valList, v)
        end
        sort!(valList)
        valDict = Dict{String, UInt8}()
        for (i, v) in enumerate(valList)
            valDict[v] = i
        end
        spec.catStrTransforms[fs] = Pair(valDict, valList)
    end
    println("CatStrTransforms set up for:", keys(counts))
end

function loadFeatSpec(csvName::String="featspec.csv")
    for line in eachline(csvName)
        startswith(line, '#') && continue
        lineVec = map(strip, split(chomp(line), ','))
        if length(lineVec) == 7
            fs = Featspec(lineVec)
            push!(spec.featspecs, fs)
            spec.featspecDict[fs.name] = fs
        end
    end
end
