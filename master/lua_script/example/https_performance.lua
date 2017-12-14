-- https_performance.lua
-- 2017-12-11
-- xzc

local network_mgr = network_mgr
local conn_mgr = require "network.conn_mgr"

local IP = "0.0.0.0"
local PORT = 8887

local url_tbl =
{
    'GET / HTTP/1.1\r\n',
    'Host: www.openssl.com\r\n',
    'Connection: keep-alive\r\n',
    'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n',
    'Upgrade-Insecure-Requests: 1\r\n',
    --'User-Agent: Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)'
    --'User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.112 Safari/537.36\r\n',
    --'Accept-Encoding: gzip, deflate, sdch\r\n',
    'Accept-Language: zh-CN,zh;q=0.8\r\n\r\n',
}
local url_page = table.concat( url_tbl )

local page200 = 
{
    'HTTP/1.1 200 OK\r\n',
    'Content-Length: %d\r\n',
    'Content-Type: text/html\r\n',
    'Server: Mini-Game-Distribute-Server/1.0\r\n',
    'Connection: close\r\n\r\n%s'
}
page200 = table.concat( page200 )

local no_cert_idx = network_mgr:new_ssl_ctx( 4 )
print( "create no cert ssl ctx at ",no_cert_idx )

local srv_idx = network_mgr:new_ssl_ctx( 4,
    "certs/server.cer",2,"certs/srv_key.pem","mini_distributed_game_server" )
print( "create server ssl ctx at ",srv_idx )

local Clt_conn = oo.class( "Clt_conn" )

function Clt_conn:conn_new( ecode )
    if 0 ~= ecode then
        print( "clt_conn conn error" )
        return
    end

    network_mgr:set_conn_io( conn_id,network_mgr.IOT_SSL,no_cert_idx )
    network_mgr:set_conn_codec( conn_id,network_mgr.CDC_NONE )
    network_mgr:set_conn_packet( conn_id,network_mgr.PKT_HTTP )

    print( "conn_new",conn_id )
end

function Clt_conn:conn_del()
    print("conn_del")
end

function Clt_conn:command_new( url,body )
    print("clt command new",url,body)
end

local Srv_conn = oo.class( "Srv_conn" )

function Srv_conn:__init( conn_id )
    self.conn_id = conn_id
end

function Srv_conn:listen( ip,port )
    self.conn_id = network_mgr:listen( ip,port,network_mgr.CNT_HTTP )
end

function Srv_conn:accept_new( new_conn_id )
    print( "srv conn accept new",new_conn_id )

    local new_conn = Srv_conn( new_conn_id )
    network_mgr:set_conn_io( new_conn_id,network_mgr.IOT_SSL,srv_idx )
    network_mgr:set_conn_codec( new_conn_id,network_mgr.CDC_NONE )
    network_mgr:set_conn_packet( new_conn_id,network_mgr.PKT_HTTP )

    return new_conn
end

function Srv_conn:conn_del()
    print( "srv conn del",self.conn_id )
end

-- http回调
function Srv_conn:command_new( url,body )
    print( "http_command_new",self.conn_id,url,body )

    local tips = "Mini-Game-Distribute-Server!\n"
    local ctx = string.format( page200,string.len(tips),tips )

    network_mgr:send_raw_packet( conn_id,ctx )
end

-- 在浏览器输入https://127.0.0.1:8887来测试
local http_listen = Srv_conn()
http_listen:listen( IP,PORT )
PLOG( "https listen at %s:%d",IP,PORT )

local ssl_port = 443
local ssl_url = "www.openssl.com"
local ip1,ip2 = util.gethostbyname( ssl_url )

local url_conn_id = network_mgr:connect( ip1,ssl_port,network_mgr.CNT_HTTP )
print( "connnect to https ",ssl_url,ip1,url_conn_id )
