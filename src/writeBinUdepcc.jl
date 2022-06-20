# write_bin_depcc.jl

#include("binarizeUdepcc.jl")
#= Bindoc layout, s = section; 
0 <count_8>
<key0_8> <key_16>
...
<tier_8> ...
...
=#

function writeEncodedDoc(f, docdat)
    b = 0
    for (i, t) in enumerate(docdat.tiers)
        b += write(f, docdat.keys[i])
        b += writeTierInfoFs[t+1](f, docdat, i)
    end
    return b
end

function writeTier_0_TokenInfo(f, docdat, i)
    b=0
    docdat.key[i] == 0 && (b += writeShortCodeMap(f, docdat, i))  # nothing to write for <newSen>, just <newDoc>.
    return b
end

function writeShortCodeMap(f, docdat, i)
    b += write(f, docdat.vals[:numshortcodes])
    for i in docdat.ix
        b += write(f, docdat.shortcodes0[i], docdat.shortcodes[i])
    end
    return b
end

function writeTier_1_TokenInfo(f, docdat, i)
    return 0
end

function writeTier_2_TokenInfo(f, docdat, i)
    return writeFormLemmaCode(f, docdat, i)
end

function writeTier_3_TokenInfo(f, d, i)
    b = write(f, d.utok.headOffset)
    b += writeTier_2_TokenInfo(f, d, i)
    return b
end

function writeTier_4_TokenInfo(f, d, i)
    b = write(f, d.utok.depRel)
    b += writeTier_3_TokenInfo(f, d, i)
    return b
end

function writeTier_5_TokenInfo(f, d, i)
    b = write(f, d.utok.case << 4 | d.utok.entity)
    b += writeTier_4_TokenInfo(f, d, i)
    return b
end

function writeTier_6_TokenInfo(f, d, i)
    b = write(f, d.utok.upos)
    b += writeTier_5_TokenInfo(f, d, i)
    return b
end

function writeFormLemmaCode(f, docdat, i)
    fl0 = docdat.utoks.formlemma0[i]
    fl = docdat.utoks.formlemma[i]
    scode = vocabdat[VocabCode(fl0,fl)]
    if scode > 0
        b += write(f, scode-1)
    elseif fl0 == 0 
        b+= write(f, fl0)
    else b += write(f, fl0, fl)
    end
    return b
end

const writeTierInfoFs = [
    writeTier_0_TokenInfo,
    writeTier_1_TokenInfo, 
    writeTier_2_TokenInfo, 
    writeTier_3_TokenInfo, 
    writeTier_4_TokenInfo, 
    writeTier_5_TokenInfo,
    writeTier_6_TokenInfo
]
