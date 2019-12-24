function stop()
    for f, _ in boundless.eventListeners(boundless.events.onEnterFrame) do
        print(boundless.removeEventListener(boundless.events.onEnterFrame, f))
    end
    for id, _ in os.intervals() do
        print(os.clearInterval(id))
    end
    for id, _ in os.timeouts() do
        print(os.clearTimeout(id))
    end
end
stop()

function setBlock(x, y, z, blockType, color)
    local p = boundless.wrap(boundless.UnwrappedBlockCoord(x, y, z))
    local c = boundless.ChunkCoord(p)
    boundless.loadChunkAnd8Neighbours(c, function (chunks)
        local v = boundless.getBlockValues(p)
        v.blockType = blockType
        v.blockMeta = 0
        v.blockColorIndex = color
        boundless.setBlockValues(p, v)
    end)
end

function getBlockType(p)
    local c = boundless.ChunkCoord(p)
    local blockValues
    boundless.loadChunkAnd8Neighbours(c, function (chunks)
        blockValues = boundless.getBlockValues(boundless.BlockCoord(p))
    end)
    return blockValues
end

function readAll(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

local arenaY = 40
local arenaSize = 50
local wallRadius = 40
local wallRadiusSq = wallRadius * wallRadius
local floorY = -math.floor(wallRadius * 0.3)

local arenaPos
for c in boundless.connections() do
    local e = boundless.getEntity(c:get_id())
    if e then
        local playerPos = e:get_position()
        arenaPos = boundless.wrap(boundless.UnwrappedBlockCoord(
            math.floor(playerPos.x / 128) * 128 + 64,
            0,
            math.floor(playerPos.z / 128) * 128 + 64))

        setBlock(arenaPos.x - 10, arenaY + floorY, arenaPos.z, boundless.blockTypes.MANTLE_DEFAULT_BASE, 0)
        e:set_position(boundless.wrap(boundless.UnwrappedWorldPosition(arenaPos.x - 10, arenaY + floorY + 2, arenaPos.z)))
    end
end

function setArenaBlock(x, y, z, blockType, color)
    setBlock(arenaPos.x + x, arenaY + y, arenaPos.z + z, blockType, color)
end

function spawnTree(bx, by, bz)
    print("spawnTree", bx, by, bz)
    for x = -1, 1 do
        for y = 4, 7 do
            for z = -1, 1 do
                setBlock(bx + x, by + y, bz + z, boundless.blockTypes.WOOD_LUSH_LEAVES, 0)
            end
        end
    end
    for y = 1, 5 do
        setBlock(bx, by + y, bz, boundless.blockTypes.WOOD_ANCIENT_TRUNK, 0)
    end
end

local fightTeleportColor = 78

function createArena()
    local c;
    c = coroutine.create(function()
        for x = -arenaSize, arenaSize do
            for y = -arenaSize, arenaSize do
                for z = -arenaSize, arenaSize do
                    local dXZ = x*x + z*z
                    local d = y*y + dXZ
                    if d < wallRadiusSq or (dXZ < 25) then
                        if y <= floorY then
                            if (x % 8 == 2 or x % 8 == 6) and (z % 8 == 2 or z % 8 == 6) then
                                setArenaBlock(x, y, z, boundless.blockTypes.ROCK_MARBLE_DECORATIVE_FRIEZE1, 228)
                            elseif (x % 8 == 0) or (z % 8 == 0) then
                                setArenaBlock(x, y, z, boundless.blockTypes.ROCK_MARBLE_DECORATIVE_FRIEZE0, 110)
                            else
                                setArenaBlock(x, y, z, boundless.blockTypes.ROCK_MARBLE_REFINED, 228)
                            end
                        elseif y >= 10 and y < 12 then
                            setArenaBlock(x, y, z, boundless.blockTypes.GLASS_DEFAULT_PLAIN, 0)
                        else
                            setArenaBlock(x, y, z, boundless.blockTypes.AIR, 0)
                        end
                    elseif d > wallRadiusSq and d < wallRadiusSq + 100 then
                        if y > 15 then
                            setArenaBlock(x, y, z, boundless.blockTypes.GLASS_DEFAULT_PLAIN, 0)
                        else
                            setArenaBlock(x, y, z, boundless.blockTypes.MANTLE_DEFAULT_BASE, 0)
                        end
                    end
                end
            end
            coroutine.yield()
        end

        setArenaBlock(0, floorY, 0, boundless.blockTypes.SOIL_SILTY_BASE_DUGUP, 0)
        spawnTree(arenaPos.x, arenaY + floorY, arenaPos.z)

        for x = -1, 1 do
            for z = -1, 1 do
                setArenaBlock(32 + x, floorY, z, boundless.blockTypes.MANTLE_DEFAULT_BASE, fightTeleportColor)
            end
        end
    end)
    local id;
    id = os.setInterval(function()
        if coroutine.resume(c) then
        else
            print("done!")
            os.clearInterval(id)
        end
    end, 20)
end

createArena()

function startFight()
    print("Trigger start fight")
    for c in boundless.connections() do
        local e = boundless.getEntity(c:get_id())
        if e then
            e:set_position(boundless.wrap(boundless.UnwrappedWorldPosition(arenaPos.x, arenaY + 13, arenaPos.z)))
        end
    end
end

local lastBlockType = boundless.blockTypes.AIR
local trySpawnTree
local nextBlock = boundless.UnwrappedBlockCoord(0, 0, 0)
function onEnterFrame()
    for c in boundless.connections() do
        local e = boundless.getEntity(c:get_id())
        if e then
            posUnderFeet = e:get_position():withYOffset(-0.5)
            blockValues = getBlockType(posUnderFeet)
            blockType = blockValues.blockType

            local rootType = boundless.getBlockTypeData(blockValues.blockType).rootType
            if rootType ~= boundless.blockTypes.AIR then
                blockType = rootType
            end

            local arenaX = posUnderFeet.x - arenaPos.x
            local arenaZ = posUnderFeet.z - arenaPos.z

            -- print(boundless.getBlockTypeData(lastBlockType).name)

            if lastBlockType == boundless.blockTypes.AIR then
                if blockType == boundless.blockTypes.SOIL_SILTY_BASE_DUGUP then
                    print("Trigger tree spawn")
                    trySpawnTree = posUnderFeet
                end
                if blockType == boundless.blockTypes.MANTLE_DEFAULT_BASE then
                    if blockValues.blockColorIndex == fightTeleportColor then
                        startFight()
                    end
                end
            end

            if trySpawnTree ~= nil then
                local treeX = trySpawnTree.x - posUnderFeet.x
                local treeZ = trySpawnTree.z - posUnderFeet.z
                -- lets the player get away from the tree that is about to spawn
                if treeX * treeX + treeZ * treeZ > 4 then
                    spawnTree(math.floor(trySpawnTree.x), math.floor(trySpawnTree.y), math.floor(trySpawnTree.z))
                    trySpawnTree = nil
                end
            end

            lastBlockType = blockType
        end
    end
end

boundless.addEventListener(boundless.events.onEnterFrame, onEnterFrame)
