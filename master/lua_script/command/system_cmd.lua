
local SS = SS
local g_command_mgr = g_command_mgr
local g_network_mgr = g_network_mgr

local g_rpc = g_rpc

-- 收到另一个服务器主动同步
local function srv_syn( srv_conn,pkt )
    if not g_network_mgr:srv_register( srv_conn,pkt ) then return false end
    if not g_command_mgr:do_srv_register( srv_conn,pkt  ) then return false end

    srv_conn:authorized( pkt.session )

    local _pkt = g_network_mgr:register_pkt( g_command_mgr )
    g_command_mgr:srv_send( srv_conn,SS.SYS_ACK,_pkt )

    PLOG( "%s register succes",srv_conn:conn_name() )

    Main.one_wait_finish( pkt.name,1 )
end

-- 自己主动同步对方，对方服务器返回同步信息
local function srv_ack( srv_conn,pkt )
    if not g_network_mgr:srv_register( srv_conn,pkt ) then return false end
    if not g_command_mgr:do_srv_register( srv_conn,pkt  ) then return false end

    srv_conn:authorized( pkt.session )

    PLOG( "%s register succes",srv_conn:conn_name() )

    Main.one_wait_finish( pkt.name,1 )
end

-- 心跳包
local function srv_beat( srv_conn,pkt )
    if pkt.response then
        g_command_mgr:srv_send( srv_conn,SS.SYS_BEAT,{response = false} )
    end

    -- 在这里不用更新自己的心跳，因为在on_command里已自动更新
end

-- 这里注册系统模块的协议处理
g_command_mgr:srv_register( SS.SYS_BEAT,srv_beat,true,false )

g_command_mgr:srv_register( SS.SYS_SYN,srv_syn,true,true )
g_command_mgr:srv_register( SS.SYS_ACK,srv_ack,true,true )

g_command_mgr:srv_register( SS.RPC_REQ,g_rpc.dispatch,true,false,true )
g_command_mgr:srv_register( SS.RPC_RES,g_rpc.response,true,false,true )

if Main.srvname == "gateway" then
    g_command_mgr:srv_register( SS.CLT_CMD,g_command_mgr.ssc_tansport,true,false,true )
end

if Main.srvname == "world" then
    -- 用一个closure来保存self
    g_command_mgr:srv_register( SS.CLT_CMD,
        g_command_mgr.css_dispatcher( g_command_mgr ),true,false,true )
end