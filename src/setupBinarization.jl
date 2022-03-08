# Setup global tiered dictionary for binarizing DepCC data

using Unicode, BSON, JSON3, AWS, AWSS3, FilePathsBase
include("binTierDefs.jl")

#using TimerOutputs #Profile

#using Debugger
#break_on(:error)

#const timerOutput = TimerOutput()
#TimerOutputs.complement!(timerOutput)

#include("memoryUtils.jl")

function prepBinaryScheme()
    println("Prepping binary schema")
    #reset_timer!()
    @time extractEnglishVocab()
    open(fetchIfNotLocal(spec, :tierSource)) do fi
        collectFeatureInfoFromDepcc()
        open("../" * spec.tierFile, "w") do fo
            for tierNum in 1:spec.numTiers
                println("Setting up tier ", tierNum)
                tupleCounts = collectTierKeyCounts(tierNum)
                writeTierInfo(fo, tierNum, tupleCounts, spec)
            end
        end
    end
    bson(spec.specFile, a=spec)
end

function fetchIfNotLocal(spec, property)
    #awsconfig = global_aws_config(; region=spec.awsRegion) 
    largeDataFile = getproperty(spec, property)
    #println("Fetching S3 object:", spec.s3bucket, field)
    #AWSS3.s3_get_file(awsconfig, spec.s3bucket, field, largeDataFile)
    return largeDataFile
end

# collectCounts: Counts for each tier are collected in separate passes over a sample chunk 
#                of depcc data. Counts for later tiers cannot be determined until keys for 
#                earlier tiers are ruled out.
function collectTierKeyCounts(tierNum)
    tupleCounts = Dict{UdepTokenCore, Int32}()
    sizehint!(tupleCounts, 500000)
    rootID = -1
    for line in eachline(spec.tierSource)
        (length(line)<=0 || line[1] == '#') && continue   #### refine this later
        t, rootID = conlluLineToUdepCore(line, rootID)
        t.formLemma0 <= 0 && continue
        id = 0 
        id, = getTierKeyId(t, tierNum-1)
        if id == 0
            key = tierKeyFs[tierNum](t)
            tupleCounts[key] = get(tupleCounts, key, 0) + 1
            #println("85 key:", key, " count:", tupleCounts[key])
        end
    end 
    println("Tuplecounts length: ", length(tupleCounts), " ", sizeof(tupleCounts))
    return tupleCounts
end

function writeTierInfo(f, tierNum, tupleCounts, spec)
    sortedCounts = sort!(collect(tupleCounts), rev=true, by=x->getindex(x,2))
    x = length(spec.tierList) + 1
    for (k,c) in sortedCounts  # keep only the tier keys above the frequency threshold
        if (c < spec.tierThreshold && tierNum < spec.numTiers) || x >= typemax(UInt8)
            push!(spec.tierIndices, x)
            break
        end
        spec.tierDict[k] = x
        push!(spec.tierList, k)
        writePretty(f, k) #, spec.vocabDictVec) 
        write(f, spec.delimChar, string(c), "\n")
        x += 1
    end
end

#@time extractEnglishVocab(InitModelSpec())
##@time prepBinaryScheme()
##print_timer(timerOutput)
