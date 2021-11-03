# Setup global tiered dictionary for binarizing DepCC data
##

using Unicode
using BSON

include("UDepUtils.jl") 

function InitModelSpec()::ModelSpec
    delimChar = '\t'
    spec =  ModelSpec(delimChar,
        "/Users/irenelangkilde-geary/Projects/UDepParse/origDepcc/", #datPath
        "part-m-00009", #"part-m-19038"                     #tierSource
        "tierKeys.tsv",                                     #tierFile
        "modelSpec.bson",                                   #specFile
        5,                                                  #numTiers
        20000,                                              #tierThreshold
        [3],                                                #tierIndices
        let tmp = Dict{String,UInt8}(); sizehint!(tmp, typemax(UInt8)); tmp["<beginDoc>"]=0; tmp["<beginSen>"]=1; tmp end,   #tierDict
        let tmp = ["<beginDoc>", "<beginSen>"]; sizehint!(tmp, typemax(UInt8)); tmp end, #tierList
    )
    return spec
end

#=function Tier_2_Tuple(tok::UdepToken, delimChar)
    l = length(tok.upos)
    if l >1 && SubString(tok.upos, 1, 2) in  ["CD", "JJ", "NN", "RB", "VB"]
        join([tok.upos, tok.entity, tok.caseType, tok.depRel, tok.headOffset], delimChar)
    else
        join([tok.form, tok.lemma, tok.upos, tok.entity, tok.caseType, tok.depRel], delimChar)
    end
end  =#

function prepBinaryScheme()
    spec = InitModelSpec()
    for x in 1:spec.numTiers
        println("Setting up tier ", x)
        setupTier(x, spec)
    end
    bson(mainPath * spec.specFile, a=spec)
end

function setupTier(tierNum, spec) 
    tupleCounts = collectCounts(tierNum, spec)
    writeTierInfo(tierNum, tupleCounts, spec)
end

function collectCounts(tierNum, spec)
    tupleCounts = Dict{String,Int}()
    sizehint!(tupleCounts, 43828335)
    tierKeyFs = getTierKeyFs(spec.delimChar)
    open(spec.datPath * spec.tierSource) do f
        rootID = -1
        for line in eachline(f)
            (length(line)<=0 || line[1] == '#') && continue   #### refine this later
            tok, rootID = conlluLineToUdep(line, rootID, spec.delimChar)
            found =false
            for x in 1:tierNum-1
                key = tierKeyFs[x](tok) #Eg: Tier_1_Tuple(tok)
                if haskey(spec.tierDict, key)
                    found = true
                    break
                end
            end
            if !found
                key = tierKeyFs[tierNum](tok)
                tupleCounts[key] = get(tupleCounts, key, 0) + 1
            end
        end
    end 
    return tupleCounts
end

function writeTierInfo(tierNum, tupleCounts, spec)
    sortedCounts = sort(collect(tupleCounts), rev=true, by=x->getindex(x,2))
    tierNum == 5 && println("lengths tierDict: ", length(spec.tierDict), " sortedCounts: ", length(sortedCounts))
    tierDict = spec.tierDict
    tierList = spec.tierList
    flag = if (tierNum == 1) "w" else "a" end
    sum = 0
    x = length(tierDict)
    push!(spec.tierIndices,x)
    open(mainPath * spec.tierFile, flag) do f
        for (k,c) in sortedCounts
            ((c < spec.tierThreshold && tierNum < spec.numTiers) || x+1 >= typemax(UInt8)) && break
            tierDict[k] = x
            push!(tierList, k)
            write(f, k * spec.delimChar * string(c) * "\n")
            x += 1
            sum += c
        end
    end
    println("Sum: ", sum)
end

@time prepBinaryScheme()

function extractEnglishVocab(delimChar)
    vocabList = Vector{String}()
    open(mainPath * "kaikki.org-dictionary-English.json") do fr
        for line in eachline(fr)
            j = JSON.parse(line)
            if j["lang_code"] == "en"
                word0 = j["word"]
                if (!isvalid(word0)) continue end
                caseT = caseType(word0)
                word = lowercase(word0)
                form_of0 = ""
                if haskey(j, "senses")
                    for s in j["senses"]
                        if haskey(s, "form_of")
                            for f in s["form_of"]
                                form_of = lowercase(f["word"])
                                if (form_of != "")
                                    push!(vocabList, word * delimChar * form_of * delimChar * caseT)
                                    form_of0 = form_of
                                end
                            end
                        end
                    end
                end
                if form_of0 == "" 
                    push!(vocabList, word * delimChar * word * delimChar * caseT)
                end
                if haskey(j, "forms")
                    for f in j["forms"]
                        form = f["form"]
                        if isvalid(form)
                            push!(vocabList, lowercase(form) * delimChar * word * delimChar * caseType(form))
                        end
                    end
                end
            end
        end
    end
    open(mainPath * "wiktionaryVocab.txt", "w") do fw
        entry = ""
        for e in sort(vocabList)
            if e != entry
                write(fw, e * '\n')
                entry = e
            end
        end
    end
end

@time extractEnglishVocab('\t')

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

