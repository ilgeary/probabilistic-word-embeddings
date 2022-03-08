# Utilities for dealing with UDep data

#=function readTierInfo(model)
    tierDict = model.tierDict
    tierList = model.tierList
    open(spec.tierFile) do f
        for (i0, line) in enumerate(eachline(f))
            i = i0 + 2
            k = chop(line)
            tierDict[k] = i
            push!(tierList, k)
        end
    end
    println("Done loading tier info!", sum)
end =#

#= 
function readVocabDict()
    iCounts = Dict{String,UInt}()
    open(mainPath * "alphaSorted-enwiki-20190320-words-frequency.txt") do f
        c=0
        for line in eachline(f)
            (line < "a-" || line > "zzzzzzzzzzz" || !isascii(line)) && continue
            c += 1
            if c >= typemax(UInt16) 
                println(line)
                c = 0
            end
        end
    end
end =#
#=            l = split(line, " ")
            k0 = l[1]
            i2 = thisind(k0, firstindex(k0)+1)
            i = min(lastindex(k0), i2)
            k = SubString(k0, firstindex(k0), i)
            #k = UInt8(char2Group(k0, line))
            isascii(k) && (iCounts[k] = get(iCounts, k, 0) + 1)
        end
    end
    x=0
    i=1
    for (k,c) in sort(collect(iCounts))
        println(i, " ", k, " ", c)
        x += c
        i += 1
        if x > typemax(UInt16) 
            x=0
            println("65K!!!")
        end
    end
    println("Len: ", length(iCounts))
end
=#
