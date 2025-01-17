-- web_stat.lua http 查询服务器状态接口

local Web_stat = oo.singleton( ... )

local json = require "lua_parson"

--[[
    curl 127.0.0.1:10003/web_stat
    curl -l --data 'gateway' 127.0.0.1:10003/web_stat
]]
function Web_stat:exec( conn,fields,body )
    -- 未指定进程名或者查询的是当前进程
    if "" == body or body == g_app.srvname then
        local total_stat = g_stat.collect()

        local ctx = json.encode(total_stat)

        return HTTPE.OK_NIL,ctx
    end

    -- 通过rpc获取其他进程数据
    local srv_conn = g_network_mgr:get_conn_by_name(body)
    if not srv_conn then
        return HTTPE.INVALID,body
    end

    -- TODO:这个rpc调用有问题，不能引用conn为up value的，conn可能会被客户端断开
    g_rpc:proxy(srv_conn,
        function(ecode,ctx)
            return g_httpd:do_return(
                conn,0 == ecode,HTTPE.OK_NIL,json.encode(ctx))
        end
    ):rpc_stat()
    return HTTPE.PENDING -- 阻塞等待数据返回
end

local wst = Web_stat()

return wst
