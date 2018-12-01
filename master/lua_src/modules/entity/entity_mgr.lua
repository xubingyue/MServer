-- entity_mgr.lua
-- xzc
-- 2018-11-20

-- 实体管理

local ET = require "modules.entity.entity_header"

local Entity_npc = require "modules.entity.entity_npc"
local Entity_player = require "modules.entity.entity_player"
local Entity_monster = require "modules.entity.entity_monster"

local Entity_mgr = oo.singleton( nil,... )

function Entity_mgr:__init()
    self.entity = {} -- 以实体唯一id为key
    self.entity_player = {} -- 以玩家id为key
end

-- 根据实体Id获取实体
function Entity_mgr:get_entity(id)
    return self.entity[id]
end

-- 根据玩家Id获取玩家实体
function Entity_mgr:get_player(pid)
    return self.entity_player[pid]
end

-- 创建实体
function Entity_mgr:new_entity( et,... )
    local entity = nil
    local eid = 111

    if ET.NPC == et then
        entity = Entity_npc(eid,...)
    elseif ET.PLAYER == et then
        entity = Entity_player(eid,...)
        self.entity_player[entity.pid] = entity
    elseif ET.MONSTER == et then
        entity = Entity_monster(eid,...)
    else
        assert( false,string.format("unknow entity type:%d",et) )
    end

    return entity
end

-- 删除实体
function Entity_mgr:del_entity( eid )
    local entity = self.entity[eid]
    if not entity then
        return ELOG("del entity fail,no such entity")
    end

    self.entity[eid] = nil
    if ET.PLAYER == entity.et then
        self.entity_player[entity.pid] = nil
    end
end

-- 删除玩家实体
function Entity_mgr:del_entity_player( pid )
    local entity = self.entity_player[pid]
    if not entity then
        return ELOG("del entity player fail,no such entity")
    end

    self.entity_player[pid] = nil
    self.entity[entity.eid] = nil
end

local entity_mgr = Entity_mgr()

return entity_mgr
