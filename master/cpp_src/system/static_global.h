#ifndef __STATIC_GLOBAL_H__
#define __STATIC_GLOBAL_H__

#include "statistic.h"
#include "../log/thread_log.h"
#include "../lua_cpplib/lev.h"
#include "../net/io/ssl_mgr.h"
#include "../thread/thread_mgr.h"
#include "../lua_cpplib/lstate.h"
#include "../net/codec/codec_mgr.h"
#include "../lua_cpplib/lnetwork_mgr.h"

/* 管理全局static或者global变量
 * 控制全局、静态变更的创建、销毁顺序，避免影响内存管理
 * static initialization order fiasco(https://isocpp.org/wiki/faq/ctors)
 * 其他静态变量只能是局部的，用get函数获取，参考object_pool的用法
 *
 * initializer只放业务无关的初始化，比如全局锁、ssl初始化...
 * 业务逻辑的初始化放initialize函数
 * 业务逻辑的销毁放uninitialize函数。业务逻辑必须在这里销毁，不能等到static对象析构 !!!
 * 因为其他局部变量在main函数之后销毁了
 */
class static_global
{
public:
    static void initialize();  /* 程序运行时初始化 */
    static void uninitialize(); /* 程序结束时反初始化 */

    static class ev *ev() { return _ev; }
    static class lev *lua_ev() { return _ev; }
    static lua_State *state() { return _state->state(); }
    static class ssl_mgr *ssl_mgr() { return _ssl_mgr; }
    static class codec_mgr *codec_mgr() { return _codec_mgr; }
    static class statistic *statistic() { return _statistic; }
    static class thread_log *async_log() { return _async_log; }
    static class thread_mgr *thread_mgr() { return _thread_mgr; }
    static class lnetwork_mgr *network_mgr() { return _network_mgr; }
private:
    class initializer // 提供一个等级极高的初始化
    {
    public:
        ~initializer();
        explicit initializer();
    };
private:
    static class lev          *_ev;
    static class lstate       *_state;
    static class ssl_mgr      *_ssl_mgr;
    static class codec_mgr    *_codec_mgr;
    static class statistic    *_statistic;
    static class thread_log   *_async_log;
    static class thread_mgr   *_thread_mgr;
    static class lnetwork_mgr *_network_mgr;

    static class initializer  _initializer;
};

#endif /* __STATIC_GLOBAL_H__ */
