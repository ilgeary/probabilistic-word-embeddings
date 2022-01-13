# Setup global tiered dictionary for binarizing DepCC data
##

using Unicode, BSON, JSON3, AWS, AWSS3, FilePathsBase
using TimerOutputs #Profile

#using Debugger
#break_on(:error)

#const timerOutput = TimerOutput()
#TimerOutputs.complement!(timerOutput)


include("UDepUtils.jl")
#include("memoryUtils.jl")

function initModelSpec()::ModelSpec
    delimChar = '\t'
    vocabSize = 1200000
    beginDocTok = UdepTokenBase(1, 0, 0, 0, 0, 0, 0) # upos=1="<beginDoc>"
    beginSenTok = UdepTokenBase(2, 0, 0, 0, 0, 0, 0) # upos=2="<beginSen>"
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
        let tmp = Vector(); sizehint!(tmp, 16); tmp end,         #vocabDictVec
        let tmp = Vector(); sizehint!(tmp, vocabSize); tmp end,  #vocabList
        let tmp = Vector(); sizehint!(tmp, vocabSize); tmp end,  #lemmaList
    )
    return spec
end

const spec = initModelSpec()

function prepBinaryScheme()
    #reset_timer!()
    #spec = InitModelSpec()
    @time extractEnglishVocab(spec)
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
    largeDataFile = "../" * field * ".gitignored"
    #println("Fetching S3 object:", spec.s3bucket, field)
    #AWSS3.s3_get_file(awsconfig, spec.s3bucket, field, largeDataFile)
    return largeDataFile
end

# collectCounts: Counts for each tier are collected in separate passes over a sample chunk 
#                of depcc data. Counts for later tiers cannot be determined until keys for 
#                earlier tiers are ruled out.
function collectTierKeyCounts(tierNum, spec)
    tupleCounts = Dict{UdepTokenBase, Int32}()
    sizehint!(tupleCounts, 500000)
    conlluLineToUdep = conlluLineToUdepF(spec.delimChar, spec.vocabDictVec)
    open(fetchIfNotLocal(spec, :tierSource)) do f
        rootID = -1
        for line in eachline(f)
            (length(line)<=0 || line[1] == '#') && continue   #### refine this later
            t, rootID, = conlluLineToUdep(line, rootID)
            t.base.form0 <= 0 && continue
            id = 0 
            id, = getTierKeyId(spec.tierDict, t.base, tierNum-1)
            if id == 0
                key = tierKeyFs[tierNum](t.base)
                tupleCounts[key] = get(tupleCounts, key, 0) + 1
                #println("85 key:", key, " count:", tupleCounts[key])
            end
        end
    end 
    println("Tuplecounts length: ", length(tupleCounts), " ", sizeof(tupleCounts))
    return tupleCounts
end

function writeTierInfo(tierNum, tupleCounts, spec)
    sortedCounts = sort!(collect(tupleCounts), rev=true, by=x->getindex(x,2))
    flag = tierNum == 1 ? "w" : "a"
    x = length(spec.tierList) + 1
    open("../" * spec.tierFile, flag) do f
        for (k,c) in sortedCounts  # keep only the tier keys above the frequency threshold
            if (c < spec.tierThreshold && tierNum < spec.numTiers) || x >= typemax(UInt8)
                push!(spec.tierIndices, x)
                break
            end
            spec.tierDict[k] = x
            push!(spec.tierList, k)
            writePretty(f, k, spec.vocabList) #, spec.vocabDictVec) 
            write(f, spec.delimChar, string(c), "\n")
            x += 1
        end
    end
end
    
function extractEnglishVocab(spec)
    vocabList, lemmaList = collectVocabDict(spec)
    open("../" * spec.vocabFile, "w") do fw
        i = writeVocabForms(fw, spec, vocabList)
        writeVocabLemmas(fw, spec, lemmaList)
    end
end

#=
    open("tmpLemmas.txt", "w") do f
        e0 = FormLemma("","")
        for e in sort!(lemmaList, lt= islessFL)
            e != e0 && write(f, e.form, "\t", e.lemma, "\n")
            e0 = e
        end
    end
    #=c = 0
    for t in tmpList
        globalVocabId(spec.vocabDictVec, t)[1] > 0 && continue
        c += 1
        println("Chunk vocab missing from wiktionary:", t)
    end
    println("Count of missing vocab:", c) =#
end =#

#=function collectChunkVocab(tierSource, delimChar)
    counts = Dict{String, UInt32}()
    sizehint!(counts, 240000)
    open(tierSource) do f
        for line in eachline(f)
            (length(line)<=0 || line[1] == '#') && continue 
            cols = split(chomp(line), delimChar)
            wf = lowercase(cols[2])  #, lowercase(cols[3]))
            counts[wf] = get(counts, wf, 0) + 1
        end
    end
    println("Length unfiltered vocabList from chunk:", length(counts))
    return counts
end =#

struct FormLemma 
    form::String
    lemma::String 
end

import Base.isless
isless(x1::FormLemma, x2::FormLemma) = x1.form < x2.form || (x1.form == x2.form && x1.lemma < x2.lemma)

function processKaikkiJsonVocabEntry(line, vocabList, lemmaList)
    #l = length(vocabList)
    #if (l % 5000 == 1) println("s119:", l, " ", vocabList[end], " mem:", get_mem_use()) end
    j = JSON3.read(line)
    pos = j["pos"]
    if j["lang_code"] == "en"
        word0 = j["word"]
        !isvalid(word0) && return
        #caseT = caseType(word0)
        word = lowercase(word0)
        push!(vocabList, word)
        form_of0 = ""
        if haskey(j, "senses")
            for s in j["senses"]
                if haskey(s, "form_of")
                    for f in s["form_of"]
                        form_of = lowercase(f["word"])
                        if (form_of != "")
                            form_of != word && push!(lemmaList, FormLemma(word, form_of))
                            #println("s135")
                            form_of0 = form_of
                        end
                    end
                end
            end
        end
        #if form_of0 == "" 
        #    push!(vocabList, VocabEntry(word, word))
        #    #println("s144")
        #end
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
                    push!(vocabList, form)
                    form != word && push!(lemmaList, FormLemma(lowercase(form), word))
                end
            end
        end 
    end
end

function collectVocabDict(spec)
    #=tmpVocabList = Vector{String}()
    sizehint!(tmpVocabList, 1500000)
    for (v,c) in collectChunkVocab(fetchIfNotLocal(spec, :tierSource), spec.delimChar)
        c> 500 && !occursin(r"[a-zA-z\d]", v) && push!(tmpVocabList, v)
    end 
    println("Length filtered tmpVocabList from chunk:", length(tmpVocabList)) =#
    vocabList = ["", "€", "--", "-", ";", "+", "(", "....", "!!", "!!!", "/", "\$", "™", ")", "...", 
                     "©", "°", ":)", "%", ",", "\"", ":", ". . .", "."] 
    sizehint!(vocabList, 1500000)
    lemmaList = Vector{FormLemma}()
    sizehint!(vocabList, 335100)
    open(fetchIfNotLocal(spec, :vocabSource)) do fr
        for line in eachline(fr)
            processKaikkiJsonVocabEntry(line, vocabList, lemmaList)
        end
    end
    println("Length total vocabList:", length(vocabList))
    println("Length total lemmaList:", length(lemmaList))
    return vocabList, lemmaList
end

# There are rare instances where a single word can have a different lemma depending on part of speech; an example is saw. For saw/NN, the lemma is saw, for saw/VBD, the lemma is see.

function writeVocabForms(fw, spec, vocabList)
    local dict
    i=0
    wordform = "Z"
    for wf in sort!(vocabList)
        #if (i % 5000 == 1) println("s185:", e, " ", get_mem_use()) end
        wf == wordform && continue
        if i % (typemax(UInt16) +1) == 0
            i = 0
            dict = Dict{String,UInt16}()
            sizehint!(dict, typemax(UInt16)+1)
            push!(spec.vocabDictVec, VocabSection(wf, dict))
            println("Section entry: ", wf)
        end
        dict[wf] = i
        push!(spec.vocabList, wf)
        write(fw, '\n', wf)
        i += 1
        wordform = wf
    end
    println("Number of vocabForms: ", length(spec.VocabList))
    return i
end

function writeVocabLemmas(fw, spec, lemmaList)
    formlemma = FormLemma("Z","Z")
    for fl in sort!(lemmaList)
        fl == formlemma && continue
        f0, fid = globalVocabId(spec.vocabDictVec, fl.form)
        l0, lid = globalVocabId(spec.vocabDictVec, fl.lemma)
        push!(spec.lemmaList, BinFormLemma(f0, l0, fid, lid))
        write(fw, '\n', fl.form, "\t", fl.lemma)
        formlemma = fl
    end
    println("Number of deduped nonidentical vocab lemmas:", length(spec.lemmaList))
end

#@time extractEnglishVocab(InitModelSpec())
@time prepBinaryScheme()
#print_timer(timerOutput)
