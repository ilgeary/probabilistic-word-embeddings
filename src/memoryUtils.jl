#memoryUtils.jl


#  Roughly track overall memory usage
function memStatusReport()
    out1 = read(`top -l1 -stats mreg,mem,rprvt,purg,vsize,vprvt -pid $(getpid())`, String)
    println("top:", out1)
    #--------
    out2 = read(`ps -p $(getpid()) -o pid,comm,pmem,lim,rss,vsz`, String)
    println("ps:", out2)
end

#https://discourse.julialang.org/t/stopping-code-if-a-given-ram-limit-is-reached/18593/7
function get_mem_use()
    f = open( "/proc/self/stat" )
    s = read( f, String )
    vsize = parse( Int64, split( s )[23] )
    mb = Int( ceil( vsize / ( 1024 * 1024 ) ) )
    return mb
end

#https://discourse.julialang.org/t/outofmemoryerror-instead-of-allocating-too-much-resources-in-the-job-scheduler/45575/2
function memOK( mb::Int, memlimit::Int )
    if( mb > memlimit )
        println("### Memory-usage too high: $mb (MB)")
        return false
    else
        return true
    end
end
