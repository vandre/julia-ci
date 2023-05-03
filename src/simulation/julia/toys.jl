using Distributed
using DistributedArrays
addprocs(4, exeflags="--project")
@everywhere using DistributedArrays
@everywhere using DistributedArrays.SPMD

d_in=d=DArray(I->fill(myid(), (map(length,I)...,)), (nworkers(), 2), workers(), [nworkers(),1])
d_out=ddata();

# define the function everywhere
@everywhere function foo_spmd(d_in, d_out, n)
    pids = sort(vec(procs(d_in)))
    pididx = findfirst(isequal(myid()), pids)
    mylp = d_in[:L]
    localsum = 0

    # Have each worker exchange data with its neighbors
    n_pididx = pididx+1 > length(pids) ? 1 : pididx+1
    p_pididx = pididx-1 < 1 ? length(pids) : pididx-1

    for i in 1:n
        sendto(pids[n_pididx], mylp[2])
        sendto(pids[p_pididx], mylp[1])

        mylp[2] = recvfrom(pids[p_pididx])
        mylp[1] = recvfrom(pids[n_pididx])

        barrier(;pids=pids)
        localsum = localsum + mylp[1] + mylp[2]
    end

    # finally store the sum in d_out
    d_out[:L] = localsum
end

# run foo_spmd on all workers
spmd(foo_spmd, d_in, d_out, 10, pids=workers())

# print values of d_in and d_out after the run
println(d_in)
println(d_out)