do
    local old = hookfunction and hookfunction(loadstring, newcclosure(function(s, ...)
        pcall(function()
            if writefile then writefile(("dump_loadstring_%d.lua"):format(os.time()), s) end
            if rconsoleprint then rconsoleprint("\n[loadstring captured]\n"..s) end
        end)
        return old(s, ...)
    end))

    -- your original call
    loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/fc6607930f2b0b3d792cb7486ddc8137.lua"))()
end
