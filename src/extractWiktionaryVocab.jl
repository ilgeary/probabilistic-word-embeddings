# extract Wiktionary Vocab

include("setupUdepccVals.jl")

function extractEnglishVocab()
    vocabList, lemmaList = collectVocabDict(spec)
    open("../" * spec.vocabFile, "w") do fw
        writeVocabForms(fw, vocabList)
        writeVocabLemmas(fw, lemmaList)
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
        globalVocabCode(spec.vocabDictVec, t)[1] > 0 && continue
        c += 1
        println("Chunk vocab missing from wiktionary:", t)
    end
    println("Count of missing vocab:", c) =#
end =#

struct FormLemmaStrings 
    form::String
    lemma::String 
end

import Base.isless
isless(x1::FormLemmaStrings, x2::FormLemmaStrings) = x1.form < x2.form || (x1.form == x2.form && x1.lemma < x2.lemma)

function isvalid(str)
    str != "" && !occursin(r"\s", str) && isascii(str)
end 

function processKaikkiJsonVocabEntry(line, vocabList, lemmaStrsList)
    #l = length(vocabList)
    #if (l % 5000 == 1) println("s119:", l, " ", vocabList[end], " mem:", get_mem_use()) end
    j = JSON3.read(line)
    pos = j["pos"]
    if j["lang_code"] == "en"
        word0 = j["word"]
        !isvalid(word0) && return
        #caps = capsType(word0)
        word = lowercase(word0)
        push!(vocabList, word)
        form_of0 = ""
        if haskey(j, "senses")
            for s in j["senses"]
                if haskey(s, "form_of")
                    for f in s["form_of"]
                        form_of = lowercase(f["word"])
                        if (form_of != "")
                            form_of != word && push!(lemmaStrsList, FormLemmaStrings(word, form_of))
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
                    form != word && push!(lemmaStrsList, FormLemmaStrings(lowercase(form), word))
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
    vocabList = ["<beginDoc>", "<beginSen>", "€", "--", "-", ";", "+", "(", "....", "!!", "!!!", "/", "\$", "™", ")", "...", 
                     "©", "°", ":)", "%", ",", "\"", ":", ". . .", "."] 
    sizehint!(vocabList, 1500000)
    append!(vocabList, [string(x) for x in 0:9]) #, spec.catStrTransforms[:cdForm])
    #spec.catStrTransforms[:cdForm] = ((),())
    lemmaList = Vector{FormLemmaStrings}()
    sizehint!(vocabList, 335100)
    for line in eachline(fetchIfNotLocal(spec, :vocabSource))
        processKaikkiJsonVocabEntry(line, vocabList, lemmaList)
    end
    println("Length total vocabList:", length(vocabList))
    println("Length total lemmaList:", length(lemmaList))
    return vocabList, lemmaList
end

# There are rare instances where a single word can have a different lemma depending on part of speech; an example is saw. For saw/NN, the lemma is saw, for saw/VBD, the lemma is see.

function writeVocabForms(fw, vocabList)
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
    println("Number of vocabForms: ", length(spec.vocabList))
    spec.vals[:vocabDictVecLength] = length(spec.vocabDictVec)
    spec.vals[:vocabListLength] = length(spec.vocabList)
end

function writeVocabLemmas(fw, formLemmaList)
    formlemma = FormLemmaStrings("Z","Z")
    for fl in sort!(formLemmaList)
        fl == formlemma && continue
        f0, fid = globalVocabCode(fl.form)
        l0, lid = globalVocabCode(fl.lemma)
        push!(spec.lemmaList, FormLemmaPair(f0, l0, fid, lid))
        write(fw, '\n', fl.form, "\t", fl.lemma)
        formlemma = fl
    end
    println("Number of deduped nonidentical vocab lemmas:", length(spec.lemmaList))
    vll = spec.vals[:vocabListLength]
    lll = length(spec.lemmaList)
    maxCode0 = codifyFormLemmaId(vll + lll)[1]
    spec.vals[:maxCode0] = maxCode0
    spec.vals[:lemmaListLength] = lll
    spec.vals[:maxShortCodes] = 1 + typemax(UInt8) - maxCode0
end
