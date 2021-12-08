# Feature definitions

include("UDepUtils.jl") 

baseFeatures = [
    u::UdepToken -> u.form
    u::UdepToken -> u.lemma
    u::UdepToken -> u.upos[1:2]
    u::UdepToken -> u.upos
    u::UdepToken -> u.entity
    u::UdepToken -> u.caseType
    u::UdepToken -> u.depRel
    u::UdepToken -> u.headOffsetSeq
    u::UdepToken -> getHeadOffsetTree()
]

rightNeighbor
leftNeighbor
head
rightSibling
leftSibling
headSibling

struct binUdep

end

