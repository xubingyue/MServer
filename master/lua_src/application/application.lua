-- application.lua
-- 2018-04-04
-- xzc

-- app进程基类

require "modules.system.define"
local Auto_id = require "modules.system.auto_id"

local Application = oo.class( ... )

-- 信号处理，默认情况下退出
--[[
/usr/include/bits/signum.h

/* Fake signal functions.  */
#define SIG_ERR	((__sighandler_t) -1)		/* Error return.  */
#define SIG_DFL	((__sighandler_t) 0)		/* Default action.  */
#define SIG_IGN	((__sighandler_t) 1)		/* Ignore signal.  */

#ifdef __USE_UNIX98
# define SIG_HOLD	((__sighandler_t) 2)	/* Add signal to hold mask.  */
#endif


/* Signals.  */
#define	SIGHUP		1	/* Hangup (POSIX).  */
#define	SIGINT		2	/* Interrupt (ANSI).  */
#define	SIGQUIT		3	/* Quit (POSIX).  */
#define	SIGILL		4	/* Illegal instruction (ANSI).  */
#define	SIGTRAP		5	/* Trace trap (POSIX).  */
#define	SIGABRT		6	/* Abort (ANSI).  */
#define	SIGIOT		6	/* IOT trap (4.2 BSD).  */
#define	SIGBUS		7	/* BUS error (4.2 BSD).  */
#define	SIGFPE		8	/* Floating-point exception (ANSI).  */
#define	SIGKILL		9	/* Kill, unblockable (POSIX).  */
#define	SIGUSR1		10	/* User-defined signal 1 (POSIX).  */
#define	SIGSEGV		11	/* Segmentation violation (ANSI).  */
#define	SIGUSR2		12	/* User-defined signal 2 (POSIX).  */
#define	SIGPIPE		13	/* Broken pipe (POSIX).  */
#define	SIGALRM		14	/* Alarm clock (POSIX).  */
#define	SIGTERM		15	/* Termination (ANSI).  */
#define	SIGSTKFLT	16	/* Stack fault.  */
#define	SIGCLD		SIGCHLD	/* Same as SIGCHLD (System V).  */
#define	SIGCHLD		17	/* Child status has changed (POSIX).  */
#define	SIGCONT		18	/* Continue (POSIX).  */
#define	SIGSTOP		19	/* Stop, unblockable (POSIX).  */
#define	SIGTSTP		20	/* Keyboard stop (POSIX).  */
#define	SIGTTIN		21	/* Background read from tty (POSIX).  */
#define	SIGTTOU		22	/* Background write to tty (POSIX).  */
#define	SIGURG		23	/* Urgent condition on socket (4.2 BSD).  */
#define	SIGXCPU		24	/* CPU limit exceeded (4.2 BSD).  */
#define	SIGXFSZ		25	/* File size limit exceeded (4.2 BSD).  */
#define	SIGVTALRM	26	/* Virtual alarm clock (4.2 BSD).  */
#define	SIGPROF		27	/* Profiling alarm clock (4.2 BSD).  */
#define	SIGWINCH	28	/* Window size change (4.3 BSD, Sun).  */
#define	SIGPOLL		SIGIO	/* Pollable event occurred (System V).  */
#define	SIGIO		29	/* I/O now possible (4.2 BSD).  */
#define	SIGPWR		30	/* Power failure restart (System V).  */
#define SIGSYS		31	/* Bad system call.  */
#define SIGUNUSED	31
]]
local sig_action = {} -- 注意，这个热更要重新注册。关服的话为默认action则无所谓



function sig_handler( signum )
    if sig_action[signum] then return sig_action[signum]() end

    SYNC_PRINTF( "catch signal %d,prepare to shutdown ...",signum )

    g_app:prepare_shutdown()

    if not g_app:check_shutdown() then
        return g_app:reg_5s_timer( g_app,g_app.check_shutdown )
    end
end

-- 初始化
function Application:__init( ... )
    self.init_list = {} -- 初始化列表
    self.command,self.srvname,self.srvindex,self.srvid = ...

    self.starttime = ev:time()
    self.session = self:srv_session(
        self.srvname,tonumber(self.srvindex),tonumber(self.srvid) )

    -- 设置当前session到C++
    network_mgr:set_curr_session( self.session )

    -- 系统定时器
    self.timer_5scb = {}
    self.auto_id = Auto_id()
end

-- 生成服务器session id
-- @name  服务器名称，如gateway、world...
-- @index 服务器索引，如多个gateway，分别为1,2...
-- @srvid 服务器id，与运维相关。开了第N个服
function Application:srv_session( name,index,srvid )
    local ty = SRV_NAME[name]

    assert( ty,"server name type not define" )
    assert( index < (1 << 24),"server index out of boundry" )
    assert( srvid < (1 << 16),   "server id out of boundry" )

    -- int32 ,8bits is ty,8bits is index,16bits is srvid
    return (ty << 24) + (index <<16) + srvid
end

-- 解析session id
function Application:srv_session_parse( session )
    local ty = session >> 24;
    local index = (session >> 16) & 0xFF
    local srvid = session & 0xFFFF

    return ty,index,srvid
end

-- 信号处理
function Application:reg_sig_action( signum,action )
    ev:signal( signum )
    sig_action[signum] = action
end

-- 准备关服
function Application:prepare_shutdown()
end

-- 检测能否关服
function Application:check_shutdown()
    local who,finished,unfinished = ev:who_busy( true )
    if not who then
        self:shutdown()
        return true
    end


    SYNC_PRINTF(
        "thread %s busy,%d finished job,%d unfinished job,waiting ...",
        who,finished,unfinished )

    return false
end

-- 关服处理
function Application:shutdown()
    g_log_mgr:close() -- 关闭文件日志线程及数据库日志线程
    g_mysql_mgr:stop() -- 关闭mysql连接

    ev:exit()
end

-- 加载各个子模块
function Application:module_initialize()
    require "modules.module_header"
end

-- 设置初始化后续动作
-- val：数量，比如说可能需要等待多个场景服务器连接
function Application:set_initialize( name,after,action,val )
    self.init_list[name] = {after = after,action = action,val = val or 1 }
end

-- 一个初始化完成
function Application:one_initialized( name,val )
    local init = self.init_list[name]
    if not init then
        return ERROR( "unknow initialize action:%s",name )
    end

    init.val = init.val - (val or 1)
    if init.val <= 0 then
        self.init_list[name] = nil
        PRINTF( "initialize one action OK:%s",name )

        for _,init in pairs( self.init_list ) do
            if init.after == name then init.action( self ) end
        end
    end

    if table.empty( self.init_list ) then self:final_initialize() end
end

-- 进程初始化
function Application:initialize()
    if g_setting.gc_stat then ev:set_gc_stat( true ) end

    if not g_command_mgr:load_schema() then
        os.exit( 1 )
    end
    for _,init in pairs( self.init_list ) do
        if not init.after and init.action then init.action( self ) end
    end
end

-- 初始化完成
function Application:final_initialize()
    -- 修正为整点触发(X分0秒)，但后面调时间就不对了
    local next = 5 - (ev:time() % 5)
    self.timer = g_timer_mgr:new_timer( next,5,self,self.do_timer )

    self.ok = true
    PRINTF( "%s server(0x%.8X) start OK",self.srvname,self.session )
end


-- 定时器事件
function Application:do_timer()
    for _,cb in pairs( self.timer_5scb ) do cb() end
end

-- 注册1s定时器
function Application:reg_5s_timer( this,method )
    local id = self.auto_id:next_id()

    self.timer_5scb[id] = oo.method_thunk( this,method )
    return id
end

-- 取消1s定时器
function Application:remove_5s_timer( id )
    self.timer_5scb[id] = nil
end

-- 运行进程
function Application:exec()
    self:reg_sig_action( 2 )
    self:reg_sig_action( 15 )

    self:initialize()

    ev:backend()
end

-- 连接db
function Application:db_initialize()
    local callback = function()
        self:one_initialized( "db_conn" )
    end
    -- 连接数据库
    g_mongodb:start( g_setting.mongo_ip,
        g_setting.mongo_port,g_setting.mongo_user,
        g_setting.mongo_pwd,g_setting.mongo_db,callback )
end

-- 加载自增id
function Application:uniqueid_initialize()
    g_unique_id:db_load()
end

-- 初始化db日志
function Application:db_logger_initialize()
    g_log_mgr:db_logger_init()
end

return Application
