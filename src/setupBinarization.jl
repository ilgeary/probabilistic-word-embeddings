# Setup global tiered dictionary for binarizing DepCC data
##
using Unicode
include("UDepUtils.jl") 
#using UDepUtils

struct ModelSpec
    delimChar::Char
    mainPath::String
    datPath::String
    modelPath::String
    tierFile::String
    tierSource::String
    numTiers::UInt8
    tierThreshold::UInt
    tierKeyFs::Vector{Function};
    tierDict::Dict{String,UInt8}
    #tierList::Vector{String}
end

function InitModelSpec()::ModelSpec
    delimChar = '\t'
    spec =  ModelSpec(delimChar,
        "/Users/irenelangkilde-geary/Projects/UDepParse/",  #mainPath
        "origDepcc/",                                       #datPath
        "model/",                                           #modelPath
        "tierKeys.tsv",                                     #tierFile
        "part-m-00009", #"part-m-19038"                     #tierSource
        5,                                                  #numTiers
        20000,                                              #tierThreshold
        [function(x) f(x, delimChar) end for f in [Tier_1_Tuple, Tier_2_Tuple, Tier_3_Tuple, Tier_4_Tuple, Tier_5_Tuple]],  #tierKeyFs
        let tmp = Dict{String,UInt8}(); sizehint!(tmp, typemax(UInt8)); tmp["<beginDoc>"]=0; tmp["<beginSen>"]=1; tmp end   #tierDict
        #let tmp = ["<beginDoc>", "<beginSen>"]; sizehint!(tmp, typemax(UInt8)); tmp end, #tierList
    )
    return spec
end



function prepBinaryScheme()
    spec = InitModelSpec()
    for x in 1:spec.numTiers
        println("Setting up tier ", x)
        setupTier(x, spec)
    end
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

function tierKeyFile(spec)
    return spec.mainPath * spec.modelPath * spec.tierFile
end

function writeTierInfo(tierNum, tupleCounts, spec)
    sortedCounts = sort(collect(tupleCounts), rev=true, by=x->getindex(x,2))
    tierNum == 5 && println("lengths tierDict: ", length(spec.tierDict), " sortedCounts: ", length(sortedCounts))
    tierDict = spec.tierDict
    #tierList = spec.tierList
    flag = if (tierNum == 1) "w" else "a" end
    sum = 0
    x = length(tierDict)
    open(tierKeyFile(spec), flag) do f
        for (k,c) in sortedCounts
            ((c < spec.tierThreshold && tierNum < spec.numTiers) || x+1 >= typemax(UInt8)) && break
            tierDict[k] = x
            #push!(tierList, k)
            write(f, k * spec.delimChar * string(c) * "\n")
            x += 1
            sum += c
        end
    end
    println("Sum: ", sum)
end


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
=#

