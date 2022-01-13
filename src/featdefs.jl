# Feature definitions

include("UDepUtils.jl") 

tokenFeats = [
    upos,
    entity,
    caseType,
    depRel,
    headOffset,
    headDir,
    basePOS,
    numberPOS,
    form,
    lemma
    #personPOS,
    #tensePOS,
]

tokenRelationships = [
    rightNeighbor,
    leftNeighbor,
    head,
    rightSibling,
    leftSibling,
    headSibling
]

relToLeftNeighbor
relToRightNeighbor
relToHeadDirNeighbor

upos(tok::UdepToken) = tok.upos
entity(tok::UdepToken) = tok.entity
caseType(tok::UdepToken) = tok.caseType
depRel(tok::UdepToken) = tok.depRel
headOffset(tok::UdepToken) = tok.headOffset
headDir(u) = sign(tok.headOffset)
basePOS(tok) = basePosDict[tok.upos]
#personPOS(u)
#tensePOS(u)
form(tok::UdepToken) = tok.form


function numberPOS(u) 
    n = agreementNumberDict[tok.upos]
    if n == agreementNumberAmbiguous 
        if u.tok in singularCDs
            return agreementNumberSingular
        else return agreementNumberPlural
        end
    else return n
    end
end

    treeOffset(u)

    lemma(u::UdepToken)

