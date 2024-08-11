-- Adds an interior

-- require("niknaks")
-- NikNaks()

TARDIS_GLOBAL_CACHED_INTPOS = nil -- init the intpos that is to be cached

function TardisFlushCachedIntpos(ply)
    TARDIS_GLOBAL_CACHED_INTPOS = nil
    print ("flushed cached intpos!")
end

if SERVER then
    function ENT:FindPosition(e)
        local creator = e:GetCreator()
        if self:CallHook("FindingPosition", e, creator) ~= true then
            creator:ChatPrint("Please wait, finding suitable spawn location for interior..")
        end

        coroutine.yield()

        local td = {}   -- stands for tracedata?
        td.mins = e.mins or e:OBBMins()
        td.maxs = e.maxs or e:OBBMaxs()

        local max = 16384
        -- local mapmaxs = NikNaks.CurrentMap:WorldMax()
        -- local mapmins = NikNaks.CurrentMap:WorldMin()


        local tries = GetConVar("hugoextension_tardis2_IntPositionAttempts"):GetInt()  -- doing this through the key instead?

        local targetframetime = 1 / 30
        local nowhere
        local highest
        local start = SysTime()
        local fallbackpos

        if TARDIS_GLOBAL_CACHED_INTPOS ~= nil then -- use cached pos if it exists

            td.start = TARDIS_GLOBAL_CACHED_INTPOS
            td.endpos = TARDIS_GLOBAL_CACHED_INTPOS

            if (not util.TraceHull(td).Hit) then  -- double check if the cached pos is still good; if not, it suggests the selected interior was changed or something got in the way
            highest = TARDIS_GLOBAL_CACHED_INTPOS
            TARDIS:Message(e:GetCreator(), "Using cached interior spawn position")
            else
            TARDIS_GLOBAL_CACHED_INTPOS = nil -- if cached pos is bad, reset it to nil so the regular position finder runs again
            end
        end





        -- if a cached pos exists, dont bother with finding a spot
    if TARDIS_GLOBAL_CACHED_INTPOS == nil then  -- ugh global var but idk how else to do this

        TARDIS:Message(e:GetCreator(), "Interior.FindingPosition")

        while tries > 0 do

            tries = tries - 1

                if (SysTime() - start) > targetframetime then
                    coroutine.yield()
                    start = SysTime()
                end

                nowhere = Vector(math.random(-max,max),math.random(-max,max),math.random(-max,max)) -- picks a totally random location on the map

--                nowhere = VectorRand(mapmins, mapmaxs)  -- uses niknaks to only test for the map's actual area, not simply the hammer size limit, saves alot of wasted attempts on small maps

                td.start = nowhere  -- tracedata start vector is now the random location??
                td.endpos = nowhere  -- tracedata end vector is also the random location??

                if (not highest) or (highest and nowhere.z > highest.z) then

                    if (not util.TraceHull(td).Hit) then  -- okay so it just does a tracehull at exactly the chosen vector to see if it is blocked

                            if self:CallHook("AllowInteriorPos",nil,nowhere,mins,maxs) ~= false then  -- literally no fucking idea what defines this function

                                -- if not NikNaks.CurrentMap:IsOutsideMap(nowhere) then

                                if util.QuickTrace(nowhere - Vector(0,0,-500), Vector(0,0,-100)).Hit == true then   -- some maps have no skybox brushes, meaning the map is exposed to the open void
                                                                                                                    -- in those cases the game thinks the map has 'space' to place an interior because it is all technically open
                                highest = nowhere                                                                   -- but since it'll spawn in the void, the entity cant work properly
                                                                                                                    -- basically this check just makes sure that map geometry actually exists where it spawns
                                end

                                -- end

                            end
                    end

                end

                        -- local fallbackposnowhere = VectorRand(mapmins, mapmaxs)  -- this one is more localized to the map, ignoring the skybox it seems

                        -- if (not util.TraceHull(td).Hit) then
                        --     if self:CallHook("AllowInteriorPos",nil,nowhere,mins,maxs) ~= false then
                        --         if not NikNaks.CurrentMap:IsOutsideMap(nowhere) then
                        --             fallbackpos = fallbackposnowhere
                        --         end
                        --     end
                        -- end

        end
    end
        print ("located interior position via standard algorithm")
--[[             if highest == nil then  -- if it didnt find a location try again with niknaks' tools

                highest = fallbackpos
                print ("used niknaks emergency fallback interior spawn location")

                if highest == nil then  -- if STILL no location found try the skybox

                    local skycam = ents.FindByClass("sky_camera")[1]

                    if IsValid(skycam) then

                        if (not util.TraceHull(td).Hit) then  -- check if skybox has enough space, to be refined later
                        highest = skycam:GetPos()
                        end
                    print ("used skybox emergency fallback interior spawn location")
                    end
                end

            end ]]


        TARDIS_GLOBAL_CACHED_INTPOS = highest
        print (highest)
        return highest

    end





    ENT:AddHook("ShouldThinkFast","interior",function(self)
        if self.findingpos then
            return true
        end
    end)

    ENT:AddHook("Think","interior",function(self)
        if self.findingpos then
            local success,res=coroutine.resume(self.findingpos)
            if coroutine.status(self.findingpos)=="dead" or (not success) then
                self.findingpos=nil
                local creator = self:GetCreator()
                if not success or not res then
                    if self:CallHook("FindingPositionFailed", self.interior, creator, res)~=true then
                        if res then
                            creator:ChatPrint("Coroutine error while finding position: "..res)
                        else
                            creator:ChatPrint("WARNING: Unable to locate space for interior, you can try again or use a different map.")
                        end
                    end
                    self.interior:Remove()
                    self.interior=nil
                    self.intready=true
                    self:CallHook("InteriorReady",false)
                    return
                end
                if self:CallHook("FoundPosition", self.interior, creator)~=true then
                    creator:ChatPrint("Done!")
                end
                local newPos = self.interior:CallHook("SetupPosition", res)
                if newPos ~= nil and isvector(newPos) then
                    res = newPos
                end
                self.interior:SetPos(res)
                self:DeleteOnRemove(self.interior)
                self.interior:DeleteOnRemove(self)
                self.interior.occupants=self.occupants -- Hooray for referenced tables
                self.interior=self.interior
                self.interior.spacecheck=nil
                self.interior:SetCollisionGroup(self.interior.oldcollisiongroup)
                self.interior:Initialize()
                self.intready=true
                self:CallHook("InteriorReady",self.interior)
            end
        end
    end)
    
    ENT:AddHook("Initialize", "interior", function(self)
        if self:CallHook("ShouldSpawnInterior") == false then
            self.intready=true
            self:CallHook("InteriorReady",false)
            return
        end
        local e=ents.Create(self.Interior)
        e.spacecheck=true
        e.exterior=self
        e.ID=self.ID
        Doors:SetupOwner(e,self:GetCreator())
        e:Spawn()
        e:Activate()
        e:CallHook("PreInitialize")
        e.oldcollisiongroup = e:GetCollisionGroup()
        e:SetCollisionGroup(COLLISION_GROUP_WORLD)
        self.interior=e
        self.findingpos = coroutine.create(self.FindPosition)
        coroutine.resume(self.findingpos,self,e)
    end)
    
    ENT:AddHook("OnRemove", "interior", function(self)
        for k,v in pairs(self.occupants) do
            self:PlayerExit(k,true)
            for int in pairs(Doors:GetInteriors()) do
                int:CheckPlayer(k)
            end
        end
    end)
else
    ENT:AddHook("SlowThink","interior",function(self)
        local inside
        for k,v in pairs(Doors:GetInteriors()) do
            if k:PositionInside(self:GetPos()) then
                inside=k
                break
            end
        end
        if IsValid(inside) then
            if self.insideof~=inside then
                if IsValid(self.insideof) and self.insideof.contains then
                    self.insideof.contains[self]=nil
                end
                self.insideof=inside
            end
            if inside.contains then
                inside.contains[self]=true
            end
        elseif IsValid(self.insideof) and self.insideof.contains then
            self.insideof.contains[self]=nil
            self.insideof=nil
        end
    end)
    
    ENT:AddHook("OnRemove","interior",function(self)
        for k,v in pairs(Doors:GetInteriors()) do
            if k.contains and k.contains[self] then
                k.contains[self] = nil
            end
        end
    end)
end







-- ------------------------------------------------------------------------------------------------------------------------------------------

-- local skycam = ents.FindByClass("sky_camera")[1]
-- local num = 0
-- if IsValid(skycam) then

--     local ang = skycam:GetAngles()
--     local pos = skycam:GetPos() + Vector(0,0,500)
--     local mask = bit.bor(MASK_SOLID, CONTENTS_PLAYERCLIP, CONTENTS_SOLID, CONTENTS_GRATE)
--     local traces = {}
--     local tdist = 1000000
--     table.insert(traces, util.TraceLine( {
--         start = pos,
--         endpos = pos + ang:Up() * tdist,
--         mask = mask
--     }))

--     table.insert(traces, util.TraceLine( {
--         start = pos,
--         endpos = pos + ang:Up() * -tdist,
--         mask = mask
--     }))

--     table.insert(traces, util.TraceLine( {
--         start = pos,
--         endpos = pos + ang:Right() * tdist,
--         mask = mask
--     }))

--     table.insert(traces, util.TraceLine( {
--         start = pos,
--         endpos = pos + ang:Right() * -tdist,
--         mask = mask
--     }))

--     table.insert(traces, util.TraceLine( {
--         start = pos,
--         endpos = pos + ang:Forward() * tdist,
--         mask = mask
--     }))

--     table.insert(traces, util.TraceLine( {
--         start = pos,
--         endpos = pos + ang:Forward() * -tdist,
--         mask = mask
--     }))


--     for k, v in pairs(traces) do num = num + (v.HitSky and 1 or 0) end


-- end

-- ------------------------------------------------------------------------------------------------------------------------------------------


--         return (num >= 1 and skycam:GetPos()) or highest




-- if SERVER then
--     function ENT:FindPosition(e)
--         local creator=e:GetCreator()
--         if self:CallHook("FindingPosition", e, creator)~=true then
--             creator:ChatPrint("Please wait, finding suitable spawn location for interior..")
--         end



--         coroutine.yield()
--         local td={}
--         td.mins=e.mins or e:OBBMins()
--         td.maxs=e.maxs or e:OBBMaxs()
--         local max=16384
--         local tries=10000
--         local targetframetime=1/30
--         local nowhere
--         local highest
--         local start=SysTime()
--         while tries>0 do
--             tries=tries-1
--             if (SysTime()-start)>targetframetime then
--                 coroutine.yield()
--                 start=SysTime()
--             end
--             nowhere=Vector(math.random(-max,max),math.random(-max,max),math.random(-max,max))
--             td.start=nowhere
--             td.endpos=nowhere
--             if ((not highest) or (highest and nowhere.z>highest.z))
--                 and (not util.TraceHull(td).Hit)
--                 and (self:CallHook("AllowInteriorPos",nil,nowhere,mins,maxs)~=false)
--             then
--                 highest = nowhere
--             end
--         end

-- ------------------------------------------------------------------------------------------------------------------------------------------
-- local num = 0
-- local skypos
-- local bbtest
-- local tdt = {}
-- tdt.mins=e.mins or e:OBBMins()
-- tdt.maxs=e.maxs or e:OBBMaxs()

-- while num <= 3 and bbtest ~= true do

-- local skycam = ents.FindByClass("sky_camera")[1]


-- if IsValid(skycam) then

--     local ang = skycam:GetAngles()
--     local pos = skycam:GetPos() + Vector(0,0,500)
--     local traces = {}
--     local tdist = 1000000

-- local skyposmod = VectorRand(-16384, 16384)
-- local skyposz = skyposmod.z - skycam:GetPos().z
    
-- skypos = skycam:GetPos() + Vector(0,0,skyposz)

-- pos = skypos

-- table.insert(traces, util.TraceLine( {
--     start = pos,
--     endpos = pos + ang:Up() * tdist,
--     mask = mask
-- }))

-- table.insert(traces, util.TraceLine( {
--     start = pos,
--     endpos = pos + ang:Up() * -tdist,
--     mask = mask
-- }))

-- table.insert(traces, util.TraceLine( {
--     start = pos,
--     endpos = pos + ang:Right() * tdist,
--     mask = mask
-- }))

-- table.insert(traces, util.TraceLine( {
--     start = pos,
--     endpos = pos + ang:Right() * -tdist,
--     mask = mask
-- }))

-- table.insert(traces, util.TraceLine( {
--     start = pos,
--     endpos = pos + ang:Forward() * tdist,
--     mask = mask
-- }))

-- table.insert(traces, util.TraceLine( {
--     start = pos,
--     endpos = pos + ang:Forward() * -tdist,
--     mask = mask
-- }))


-- for k, v in pairs(traces) do num = num + (v.HitSky and 1 or 0) end



-- if not util.TraceHull(tdt).Hit then
--     bbtest = true
--     print (bbtest)
-- end



-- end


-- end

-- ------------------------------------------------------------------------------------------------------------------------------------------

-- highest = skypos

--         return num <= 3 and skypos or highest
        
--     end