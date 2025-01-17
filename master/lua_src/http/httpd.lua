-- http deamon

local page404 =
{
    'HTTP/1.1 404 Not Found\r\n',
    'Content-Length: 0\r\n',
    'Content-Type: text/html\r\n',
    'Server: Mini-Game-Distribute-Server/1.0\r\n',
    'Connection: close\r\n\r\n'
}
page404 = table.concat( page404 )

local page500 =
{
    'HTTP/1.1 500 Internal server error\r\n',
    'Content-Length: 0\r\n',
    'Content-Type: text/html\r\n',
    'Server: Mini-Game-Distribute-Server/1.0\r\n',
    'Connection: close\r\n\r\n'
}
page500 = table.concat( page500 )

local page200 =
{
    'HTTP/1.1 200 OK\r\n',
    'Content-Length: %d\r\n',
    'Content-Type: text/html\r\n',
    'Server: Mini-Game-Distribute-Server/1.0\r\n',
    'Connection: close\r\n\r\n%s'
}
page200 = table.concat( page200 )

local network_mgr = network_mgr
local uri = require "util.uri"

require "http.http_header"
local Httpd_conn = require "http.httpd_conn"

local Httpd = oo.singleton( ... )

function Httpd:__init()
    self.conn = {}
    self.exec = {}
    self.http_listen = nil
end

-- 监听http连接
function Httpd:http_listen( ip,port )
    self.http_listen = network_mgr:listen( ip,port,network_mgr.CNT_SCCN )
    PRINTF( "listen for http at %s:%d",ip,port )

    g_conn_mgr:set_conn( self.http_listen,self )
    return true
end

-- http调用
function Httpd:do_exec( path,conn,fields,body )
    local exec_obj = require( path )
    return exec_obj:exec( conn,fields,body )
end

function Httpd:conn_accept( new_conn_id )
    network_mgr:set_conn_io( new_conn_id,network_mgr.IOT_NONE )
    network_mgr:set_conn_codec( new_conn_id,network_mgr.CDC_NONE )
    network_mgr:set_conn_packet( new_conn_id,network_mgr.PKT_HTTP )

    PRINT( "http_accept_new",new_conn_id )

    local new_conn = Httpd_conn( new_conn_id )

    self.conn[new_conn_id] = new_conn
    return new_conn
end

-- 对方断开连接
function Httpd:conn_del( conn_id )
    self.conn[conn_id] = nil
    PRINT( "http_connect_del",conn_id )
end

-- 主动断开连接
function Httpd:conn_close( conn )
    self.conn[conn.conn_id] = nil
    conn:close( true ) -- 默认情况下，http要及时发送数据
end

-- 格式化错误码为json格式
function Httpd:format_error( code,ctx )
    if not ctx then
        return string.format( '{"code":%d,"msg":"%s"}',code[1],code[2] )
    end

    if code[2] then
        return string.format(
            '{"code":%d,"msg":"%s","ctx":"%s"}',code[1],code[2],ctx )
    end

    -- 直接返回由对应功能指定的内容。比如返回一个json串，不好再放到ctx里
    return ctx
end

-- 格式化http-200返回
function Httpd:format_200( code,ctx )
    local ctx = self:format_error( code,ctx )

    return string.format( page200,string.len(ctx),ctx )
end

-- 处理返回
function Httpd:do_return(conn,success,code,ctx)
    if not success then -- 发生语法错误
        conn:send_pkt( page500 )
    else
        -- 需要异步处理数据，阻塞中
        -- TODO:要不要加个定时器做超时?
        if code == HTTPE.PENDING then return end

        conn:send_pkt( self:format_200( code,ctx ) )
    end

    return self:conn_close( conn )
end

-- http回调
function Httpd:do_command( conn,url,body )
    -- url = /platform/pay?sid=99&money=200
    local raw_url,fields = uri.parse( url )

    local path = self.exec[raw_url]
    if not path then
        -- 限定http请求的路径，不能随意运行其他路径文件
        -- 也不要随意放其他文件到此路径
        path = "lua_src/http/www" .. raw_url
        local exec_file = io.open( path .. ".lua","r" )

        if not exec_file then
            ERROR( "http request page not found:%s",raw_url )
            conn:send_pkt( page404 )

            return self:conn_close( conn )
        end

        path = string.gsub( path,"%/", "." ) -- 把/转为.来匹配lua的require格式
        -- 记录一个path而不是一个exec_obj，不影响热更，但不用每次都拼字符
        self.exec[raw_url] = path
    end

    local success,code,ctx = xpcall(
        Httpd.do_exec, __G__TRACKBACK__,httpd,path,conn,fields,body )

    return self:do_return(conn,success,code,ctx)
end

local httpd = Httpd()

return httpd
