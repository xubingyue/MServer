
local SS = SS
local g_command_mgr = g_command_mgr
local g_network_mgr = g_network_mgr

local g_rpc = g_rpc

-- 收到另一个服务器主动同步
local function srv_reg( srv_conn,pkt )
    if not g_network_mgr:srv_register( srv_conn,pkt ) then return false end
    srv_conn:authorized( pkt )

    local _pkt = g_command_mgr:command_pkt()
    srv_conn:send_pkt( SS.SYS_CMD_SYNC,_pkt )
    srv_conn:send_pkt( SS.SYS_SYNC_DONE,{} )

    PRINTF( "%s register succes",srv_conn:conn_name() )
end

-- 同步对方指令数据
local function srv_cmd_sync( srv_conn,pkt )
    g_command_mgr:other_cmd_register( srv_conn,pkt )
end

-- 对方服务器数据同步完成
local function srv_sync_done( srv_conn,pkt )
    g_app:one_initialized( srv_conn:base_name(),1 )
end

-- 服务器之间心跳包
local beat_pkt = { response = false }
local function srv_beat( srv_conn,pkt )
    if pkt.response then
        srv_conn:send_pkt( SS.SYS_BEAT,beat_pkt )
    end

    -- 在这里不用更新自己的心跳，因为在on_command里已自动更新
end

-- 其他服务器通过rpc调用gm
local function rpc_gm( where,cmd,... )
    g_gm:raw_exec( where,nil,cmd,... )
end

g_rpc:declare( "rpc_gm",rpc_gm,-1 )


-- 这里注册系统模块的协议处理
g_command_mgr:srv_register( SS.SYS_BEAT,srv_beat,true )
g_command_mgr:srv_register( SS.SYS_REG,srv_reg,true,true )
g_command_mgr:srv_register( SS.SYS_CMD_SYNC,srv_cmd_sync,true )
g_command_mgr:srv_register( SS.SYS_SYNC_DONE,srv_sync_done,true )
