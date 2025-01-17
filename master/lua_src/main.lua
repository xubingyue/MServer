-- main.lua
-- 2018-04-04
-- xzc

-- 进程入口文件

-- 设置lua文件搜索路径
package.path = "./lua_src/?.lua;" .. package.path
-- 设置c库搜索路径
package.cpath = "./c_module/?.so;" .. package.cpath

require "global.oo"
require "global.require" -- 需要热更的文件，必须放在这后面

local Log  = require "Log"
local util = require "util"
require "global.global" -- 这个要放require后面，它除了一个测试用的函数是可以热更的
local time = require "global.time"

math.randomseed( ev:time() )

local function main( command,srvname,srvindex,srvid,... )
    util.mkdir_p( "log" )  -- 创建日志目录
    util.mkdir_p( "runtime" ) -- 创建运行时数据存储目录
    util.mkdir_p( "runtime/rank" ) -- 创建运行时排行榜数据存储目录

    local deamon = false -- 是否后台模式
    for _,args in pairs( {...} ) do
        if args == "-daemon" then
            deamon = true;break
        end
    end

    -- 设置主循环临界时间，目前只用来输出日志,检测卡主循环
    ev:set_critical_time(1000)

    -- 设置错误日志、打印日志
    -- 如果你的服务器是分布式的，包含多个进程，则注意名字要区分开来
    local tm = time.ctime()

    -- win下文件名不支持特殊字符的，比如":"
    local epath = string.format( "log/%s_error",srvname )
    local mpath = string.format( "log/%s_mongo",srvname )
    local ppath = string.format(
        "log/%s#%04d-%02d-%02d#%02d_%02d_%02d",
        srvname,tm.year,tm.month,tm.day,tm.hour,tm.min,tm.sec )
    Log.set_args( deamon,ppath,epath,mpath )

    -- 非后台模式，打印进程名到屏幕，否则多个进程在同一终端开户时不好区分日志
    local app_name = string.format("%s.%d",srvname,srvindex)
    if not deamon then Log.set_name( app_name ) end

    SYNC_PRINTF( "starting %s ... ",app_name )
    local App = require( string.format( "%s.app",srvname ) )

    g_app = App( command,srvname,srvindex,srvid,... )
    g_app:exec()
end

xpcall( main, __G__TRACKBACK__,... )
