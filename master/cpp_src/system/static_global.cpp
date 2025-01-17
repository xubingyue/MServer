#include <openssl/ssl.h>
#include "static_global.h"

#include "../mysql/sql.h"
#include "../mongo/mongo.h"

class lev          *static_global::_ev          = NULL;
class lstate       *static_global::_state       = NULL;
class ssl_mgr      *static_global::_ssl_mgr     = NULL;
class codec_mgr    *static_global::_codec_mgr   = NULL;
class statistic    *static_global::_statistic   = NULL;
class thread_log   *static_global::_async_log   = NULL;
class thread_mgr   *static_global::_thread_mgr  = NULL;
class lnetwork_mgr *static_global::_network_mgr = NULL;

// initializer最高等级初始化，在main函数之前，适合设置一些全局锁等
class static_global::initializer static_global::_initializer;

int32 ssl_init();
int32 ssl_uninit();
/* will be called while process exit */
void on_exit();
/* will be called while allocate memory failed with new */
void on_new_fail();

static_global::initializer::initializer()
{
    /* https://isocpp.org/files/papers/N3690.pdf 3.6.3 Termination
     *  If a call to std::atexit is sequenced before the completion of the
     * initialization of an object with static storage duration, the call to
     * the destructor for the object is sequenced before the call to the
     * function passed to std::atexit.
     * 尽早调用atexit，这样才能保证静态变量的析构函数在onexit之前调用
     */
    atexit( on_exit );

    std::set_new_handler( on_new_fail );

    ssl_init();
    sql::library_init();
    mongo::init();
}

static_global::initializer::~initializer()
{
    sql::library_end();
    mongo::cleanup();
    ssl_uninit();
}

// 业务都放这里逻辑初始化
void static_global::initialize()  /* 程序运行时初始化 */
{
    /* 原本用static对象，但实在是无法控制各个销毁的顺序。因为其他文件中还有局部static对象
     * 会依赖这些对象。
     * 比如class lev销毁时会释放引起一些对象gc，调用局部内存池，但早就销毁了
     * 各个变量之间有依赖，要注意顺序
     * 同一个unit中的static对象，先声明的先初始化。销毁的时候则反过来
     * 在头文件中的顺序不重要，这里实现的顺序才是运行时的顺序
     */


    // 状态统计，独立的
    _statistic = new class statistic();
    _ev = new class lev();
    _thread_mgr = new class thread_mgr();
    _async_log = new class thread_log();
    _state = new class lstate();
    _codec_mgr = new class codec_mgr();
    _ssl_mgr = new class ssl_mgr();
    _network_mgr = new class lnetwork_mgr();

    _async_log->start( 1,0 );

    // 关服的时候，不需要等待这个线程。之前有人在关服定时器上打异步日志，导致这个线程一直忙
    // 关不了服。stop的时候会处理所有日志
    _async_log->set_wait_busy( false );

    // 初始化流量统计，这个和时间有关，等 ev 初始化后才调用
    _statistic->reset_trafic();
}

/* 业务逻辑都放这里销毁，不能放initializer的析构函数或者等到对应static对象析构
 * 因为业务逻辑可能包含static对象，等到调用析构的时候已经晚了
 * 比如socket的buffer对象中使用局部static内存池。如果在_network_mgr的析构里才关闭socket
 * 局部static内存池早就销毁了，内存早已出错。日志线程也是同样的设计。
 */
void static_global::uninitialize() /* 程序结束时反初始化 */
{
    _async_log->stop();
    _thread_mgr->stop();
    _network_mgr->clear();

    delete _network_mgr;
    delete _ssl_mgr;
    delete _codec_mgr;
    delete _state;
    delete _async_log;
    delete _thread_mgr;
    delete _ev;
    delete _statistic;
}


// 初始化ssl库
int32 ssl_init()
{
    /* sha1、base64等库需要用到的
     * mongo c driver、mysql c connector等第三方库可能已初始化了ssl
     * ssl初始化是不可重入的。在初始化期间不要再调用任何相关的ssl函数
     * ssl可以初始化多次，在openssl\crypto\init.c中通过RUN_ONCE来控制
     */

// OPENSSL_VERSION_NUMBER定义在/usr/include/openssl/opensslv.h
#if OPENSSL_VERSION_NUMBER < 0x10100000L
    SSL_library_init();
#else
    OPENSSL_init_ssl(0, NULL);
#endif

    SSL_load_error_strings ();
    ERR_load_BIO_strings ();
    OpenSSL_add_all_algorithms ();

    return 0;
}

int32 ssl_uninit()
{
    /* The OPENSSL_cleanup() function deinitialises OpenSSL (both libcrypto and
     * libssl). All resources allocated by OpenSSL are freed. Typically there
     * should be no need to call this function directly as it is initiated
     * automatically on application exit. This is done via the standard C
     * library atexit() function. In the event that the application will close
     * in a manner that will not call the registered atexit() handlers then the
     * application should call OPENSSL_cleanup() directly. Developers of
     * libraries using OpenSSL are discouraged from calling this function and
     * should instead, typically, rely on auto-deinitialisation. This is to
     * avoid error conditions where both an application and a library it depends
     * on both use OpenSSL, and the library deinitialises it before the
     * application has finished using it.
     */

    // OPENSSL_cleanup();

    return 0;
}

/* https://isocpp.org/files/papers/N3690.pdf
 * 3.6.3 Termination
 * static 变量的销毁与 static变更创建和std::atexit的调用顺序相关，这里可能并没统计到
 */
void on_exit()
{
    int32 counter  = 0;
    int32 counters = 0;
    global_mem_counter(counter,counters);

    // 直接用PRINTF会导致重新创建ev取时间
    // PRINTF( "new counter:%d    ----   new[] counter:%d",counter,counters );

    PRINTF_R( "new counter:%d    ----   new[] counter:%d",counter,counters );
    //back_trace();
}

void on_new_fail()
{
    FATAL( "out of memory!!! abort" );
}