# Structs for storing UDep token data
# Constructors are in uDepConstructors.jl

abstract type AbstractUdepToken end

struct UdepTokenCoreStrings <: AbstractUdepToken
    upos::String
    entity::String
    caps::String
    depRel::String
    headOffset::Int8
    form::String   # section id for form+lemma pair
    lemma::String  # entry id for form+lemma pair
end

struct UdepTokenCore <: AbstractUdepToken
    upos::UInt8
    entity::UInt8
    caps::UInt8
    depRel::UInt8
    headOffset::Int8
    formLemma0::UInt8   # section id for form+lemma pair
    formLemma::UInt16  # entry id for form+lemma pair
end

const nullUtok = UdepTokenCore(0, 0, 0, 0, typemax(Int8), 0, 0)  

function UdepTokenCore(; tok=nullUtok,
    upos    = tok.upos, 
    entity  = tok.entity, 
    caps    = tok.caps, 
    depRel  = tok.depRel, 
    headOffset  = tok.headOffset, 
    formLemma0  = tok.formLemma0, 
    formLemma   = tok.formLemma)
    UdepTokenCore(upos, entity, caps, depRel, headOffset, formLemma0, formLemma)
end
    
#entity(tok::UdepTokenCore) = tok.entity_caps >> 4
#caps(tok::UdepTokenCore) = tok.entity_caps & 0b00001111

function isless(x1::UdepTokenCore, x2::UdepTokenCore) 
    x1.formlemma0 < x2.formlemma0 || 
    (x1.formlemma0 == x2.formlemma0 && x1.formlemma < x2.formlemma)
end 

#=
struct UdepToken 
    base::UdepTokenCore
    formStr::String
    lemmaStr::String
    customCaps::Tuple{Vararg{UInt8}}
end

const nullUtok = UdepToken(
    UdepTokenCore(0, 0, 0, 0, 0, 0, 0),  ## 0 headOffset??? typemax(Int8)
    "", 
    ()
) =#

