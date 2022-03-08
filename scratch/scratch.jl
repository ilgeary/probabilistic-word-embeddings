top:Processes: 521 total, 2 running, 519 sleeping, 2914 threads 
2021/12/15 14:59:10
Load Avg: 1.78, 1.15, 1.05 
CPU usage: 2.31% user, 5.40% sys, 92.27% idle 
SharedLibs: 128M resident, 34M data, 9376K linkedit.
MemRegions: 343844 total, 4716M resident, 83M private, 1244M shared.
PhysMem: 15G used (4277M wired), 1013M unused.
VM: 5262G vsize, 1993M framework vsize, 44188075(0) swapins, 45883310(0) swapouts.
Networks: packets: 17913106/13G in, 21158020/7936M out.
Disks: 8331124/383G read, 11894546/296G written.

#MREGS MEM  RPRVT PURG VSIZE VPRVT
N/A    276M N/A   0B   N/A   N/A  

ps:  PID COMM             %MEM   LIM    RSS      VSZ
37680 /usr/local/bin/j  2.1     - 344624  6058220

Length total encVocabList:1276432
top:Processes: 522 total, 3 running, 519 sleeping, 2927 threads 
2021/12/15 14:59:28
Load Avg: 1.76, 1.19, 1.07 
CPU usage: 1.62% user, 5.40% sys, 92.97% idle 
SharedLibs: 128M resident, 35M data, 9308K linkedit.
MemRegions: 344112 total, 4767M resident, 82M private, 839M shared.
PhysMem: 16G used (4055M wired), 20M unused.
VM: 5283G vsize, 1993M framework vsize, 44188139(0) swapins, 45883310(0) swapouts.
Networks: packets: 17913299/13G in, 21158297/7936M out.
Disks: 8334965/385G read, 11894973/296G written.

#MREGS MEM  RPRVT PURG VSIZE VPRVT
N/A    482M N/A   0B   N/A   N/A  

ps:  PID COMM             %MEM   LIM    RSS      VSZ
37680 /usr/local/bin/j  3.7     - 613716  6265000

 ──────────────────────────────────────────────────────────────────
                           Time                   Allocations      
                   ──────────────────────   ───────────────────────
 Tot / % measured:      21.7s / 0.00%           14.3GiB / 0.00%    

 Section   ncalls     time   %tot     avg     alloc   %tot      avg
 ──────────────────────────────────────────────────────────────────
 ──────────────────────────────────────────────────────────────────
 ....



 Tuplecounts length: 1188963 64
 ──────────────────────────────────────────────────────────────────
                           Time                   Allocations      
                   ──────────────────────   ───────────────────────
 Tot / % measured:      71.3s / 0.00%           41.2GiB / 0.00%    

 Section   ncalls     time   %tot     avg     alloc   %tot      avg
 ──────────────────────────────────────────────────────────────────
 ──────────────────────────────────────────────────────────────────
Sum: 3628163 lengths:52 52
UdepToken(0x01, 0x00, 0x00, 0x00, 0, 0x00, 0x0000)UdepToken(0x0c, 0x07, 0x01, 0x1f, 1, 0x00, 0x0000)UdepToken(0x1c, 0x07, 0x01, 0x1c, 1, 0x06, 0xbbf4)
 ──────────────────────────────────────────────────────────────────
                           Time                   Allocations      
                   ──────────────────────   ───────────────────────
 Tot / % measured:      71.5s / 0.00%           41.3GiB / 0.00%    

 Section   ncalls     time   %tot     avg     alloc   %tot      avg
 ──────────────────────────────────────────────────────────────────
 ──────────────────────────────────────────────────────────────────
Setting up tier 2
u110:x:1Function[Tier_1_Key, Tier_2_Key, Tier_3_Key, Tier_4_Key, Tier_5_Key]
id:0 key:UdepToken(0x1e, 0x07, 0x02, 0x01, 0, 0x01, 0x1282) tier:1
u110:x:1Function[Tier_1_Key, Tier_2_Key, Tier_3_Key, Tier_4_Key, Tier_5_Key]
id:UdepToken(0x09, 0x07, 0x01, 0x2c, 0, 0x00, 0x0000) key:UdepToken(0x09, 0x07, 0x01, 0x2c, 0, 0x00, 0x0000) tier:1
ERROR: LoadError: MethodError: no method matching isless(::Int64, ::UdepToken)
Closest candidates are:
  isless(::Any, ::Missing) at missing.jl:88
  isless(::Missing, ::Any) at missing.jl:87
  isless(::Real, ::AbstractFloat) at operators.jl:168
  ...