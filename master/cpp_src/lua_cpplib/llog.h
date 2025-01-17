#ifndef __LLOG_H__
#define __LLOG_H__

#include "../global/global.h"

struct lua_State;
class thread_log;

class llog
{
public:
    ~llog();
    explicit llog( lua_State *L );

    int32 stop ( lua_State *L );
    int32 start( lua_State *L );
    int32 write( lua_State *L );

    // 用于实现stdout、文件双向输出日志打印函数
    static int32 plog( lua_State *L );
    // 用于实现stdout、文件双向输出日志打印函数
    static int32 elog( lua_State *L );
    // 设置日志参数
    static int32 set_args( lua_State *L );
    // 设置进程名
    static int32 set_name( lua_State *L );
private:
    class thread_log *_log;
};

#endif /* __LLOG_H__ */
