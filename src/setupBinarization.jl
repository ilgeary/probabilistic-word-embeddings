# Setup global tiered dictionary for binarizing DepCC data
##

using Unicode, BSON, JSON, AWS, AWSS3, FilePathsBase

if (!isdefined(Main, :tierKeyFs)) include("UDepUtils.jl") end

function InitModelSpec()::ModelSpec
    delimChar = '\t'
    vocabSize = 1215000
    beginDocTok = UdepToken(1, 0, 0, 0, 0, 0, 0) # upos=1="<beginDoc>"
    beginSenTok = UdepToken(2, 0, 0, 0, 0, 0, 0) # upos=2="<beginSen>"
    spec =  ModelSpec(delimChar, beginDocTok, beginSenTok,
        "us-east-2", # (Ohio)
        "s3://aktify-word-embeddings/",
        "originalData/depCC/part-m-00009", #"part-m-19038" #tierSource
        "originalData/wiktionary/kaikki.org-dictionary-English.json",  #vocabSource
        "model/tierKeys.tsv",                               #tierFile
        "model/wiktionaryVocab.tsv",                        #vocabFile
        "modelSpec.bson",                                   #specFile
        5,                                                  #numTiers
        20000,                                              #tierThreshold: frequency count of tier tuple for ending tier
        [3],                                                #tierIndices: first two elements are "<beginDoc>" and "<beginSen>", so tier 1 starts at index 3
        let tmp = Dict(); sizehint!(tmp, typemax(UInt8)); tmp[beginDocTok]=0; tmp[beginSenTok]=1; tmp end,   #tierDict
        let tmp = [beginDocTok, beginSenTok]; sizehint!(tmp, typemax(UInt8)); tmp end,  #tierList
        let tmp = Vector(); sizehint!(tmp, 16); tmp end,                                #vocabDict
        let tmp = Vector(); sizehint!(tmp, typemax(UInt16)); tmp end                    #vocabList
    )
    return spec
end

function prepBinaryScheme()
    spec = InitModelSpec()
    extractEnglishVocab(spec)
    for x in 1:spec.numTiers
        println("Setting up tier ", x)
        setupTier(x, spec)
    end
    bson(spec.specFile, a=spec)
    #bson("vocabDict.bson", a=spec.vocabDict) # 42M
    #bson("vocabList.bson", a=spec.vocabList) # 41M vs 29M as tsv
end

function setupTier(tierNum, spec) 
    tupleCounts = collectTierKeyCounts(tierNum, spec)
    writeTierInfo(tierNum, tupleCounts, spec)
end

function fetchIfNotLocal(spec, property)
    #awsconfig = global_aws_config(; region=spec.awsRegion) 
    field = getproperty(spec, property)
    outputFile = "../" * field * ".gitignored"
    #println("Fetching S3 object:", spec.s3bucket, field)
    #AWSS3.s3_get_file(awsconfig, spec.s3bucket, field, outputFile)
    return outputFile
end

# collectCounts: Counts for each tier are collected in separate passes over a sample chunk 
#                of depcc data. Counts for later tiers cannot be determined until keys for 
#                earlier tiers are ruled out.
function collectTierKeyCounts(tierNum, spec)
    tupleCounts = Dict{UdepToken, Int}()
    sizehint!(tupleCounts, 12000000)
    conlluLineToUdep = conlluLineToUdepF(spec.delimChar, spec.vocabDictVec)
    open(fetchIfNotLocal(spec, :tierSource)) do f
        rootID = -1
        for line in eachline(f)
            (length(line)<=0 || line[1] == '#') && continue   #### refine this later
            t, rootID = conlluLineToUdep(line, rootID)
            id, key = getTierKeyId(spec.tierDict, t.tok, tierNum-1)
            if id == 0
                key = tierKeyFs[tierNum](t.tok)
                tupleCounts[key] = get(tupleCounts, key, 0) + 1
            end
        end
    end 
    println("Tuplecounts length: ", length(tupleCounts))
    return tupleCounts
end

function writeTierInfo(tierNum, tupleCounts, spec)
    sortedCounts = sort(collect(tupleCounts), rev=true, by=x->getindex(x,2))
    tierNum == 5 && println("lengths tierDict: ", length(spec.tierDict), " sortedCounts: ", length(sortedCounts))
    flag = if (tierNum == 1) "w" else "a" end
    sum = 0
    x = spec.tierIndices[1]
    open("../" * spec.tierFile, flag) do f
        for (k,c) in sortedCounts  # keep only the tier keys above the frequency threshold
            if (c < spec.tierThreshold && tierNum < spec.numTiers) || x >= typemax(UInt8)
                push!(spec.tierIndices, x)
                break
            end
            spec.tierDict[k] = x
            push!(spec.tierList, k)
            write(f, bin2Pretty(k, spec.vocabList) * spec.delimChar * string(c) * "\n")
            sum += c
            x += 1
        end
    end
    println("Sum: ", sum)
end
    
function extractEnglishVocab(spec)
    strVocabList = collectVocabDict(spec)
    writeVocabInfo(spec, strVocabList)
end

function collectVocabDict(spec)
    delimChar = spec.delimChar
    strVocabList = Vector{String}()
    open(fetchIfNotLocal(spec, :vocabSource)) do fr
        for line in eachline(fr)
            j = JSON.parse(line)
            if j["lang_code"] == "en"
                word0 = j["word"]
                if (!isvalid(word0)) continue end
                #caseT = caseType(word0)
                word = lowercase(word0)
                form_of0 = ""
                if haskey(j, "senses")
                    for s in j["senses"]
                        if haskey(s, "form_of")
                            for f in s["form_of"]
                                form_of = lowercase(f["word"])
                                if (form_of != "")
                                    push!(strVocabList, word * delimChar * form_of)
                                    form_of0 = form_of
                                end
                            end
                        end
                    end
                end
                if form_of0 == "" 
                    push!(strVocabList, word * delimChar * word)
                end
                if haskey(j, "forms")
                    for f in j["forms"]
                        form = f["form"]
                        keep = true
                        if haskey(f, "tags")
                            tags = f["tags"]
                            for t in tags
                                if t in ["comparative", "superlative"] 
                                    keep = false
                                    break
                                end
                            end
                        end
                        if keep && isvalid(form)
                            push!(strVocabList, lowercase(form) * delimChar * word)
                        end
                    end
                end 
            end
        end
    end
    return strVocabList
end

# There are rare instances where a single word can have a different lemma depending on part of speech; an example is saw. For saw/NN, the lemma is saw, for saw/VBD, the lemma is see.

function writeVocabInfo(spec, strVocabList)
    open("../" * spec.vocabFile, "w") do fw
        dict = Dict{VocabEntry,UInt16}()
        push!(spec.vocabDictVec, VocabSection(VocabEntry("", ""), dict))
        i = 1 
        sortedVL = sort(strVocabList)
        entry = sortedVL[1]             # = form plus lemma plus case
        eFields = split(entry, spec.delimChar)   
        formlemma = VocabEntry(eFields[1], eFields[2]) # = form plus lemma
        dict[formlemma] = i
        write(fw, entry)
        for e in sortedVL[2:end]
            eFields = split(e, spec.delimChar)
            fl = VocabEntry(eFields[1], eFields[2])
            fl == formlemma && continue
            i += 1
            if i == typemax(UInt16) +1
                i = 1
                dict = Dict{VocabEntry,UInt16}()
                push!(spec.vocabDictVec, VocabSection(fl, dict))
                println("Section entry: ", fl)
            end
            dict[fl] = i
            push!(spec.vocabList, fl)
            write(fw, '\n' * e)
            entry = e
            formlemma = fl
        end
    end
end

#@time extractEnglishVocab(InitModelSpec())
@time prepBinaryScheme()

