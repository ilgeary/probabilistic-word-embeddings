# countDisjointVocab.jl

const vocab = Dict{String,UInt8}

open ("/Users/irenelangkilde-geary/Projects/UDepParse/general.txt") do f
    for l in eachline(f)
        vocab[chop(l)] = 0
    end    
end

const splitLine = 13355052 / 2

open ("/Users/irenelangkilde-geary/Projects/UDepParse/origDepcc/part-m-0000") do f
    for (i,l0) in enumerate(eachline(f))
        l = chop(l0)
        if i > splitLine
            if haskey(vocab, l)
        else 1 end
        if vocab[l] != true
    end  
end