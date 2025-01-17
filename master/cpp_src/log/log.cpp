#include <string>

#include "log.h"
#include "../pool/object_pool.h"
#include "../system/static_global.h"

// cat /usr/include/linux/limits.h | grep PATH_MAX PATH_MAX = 4096，这个太长了
#define LOG_PATH_MAX    64

/* 定义日志内容的大小 */
static constexpr size_t 
    LOG_CTX_SIZE[log::LOG_SIZE_MAX] = { 64,1024,LOG_MAX_LENGTH };

static bool is_daemon = false;    /* 是否后台运行。后台运行则不输出日志到stdout */
static char printf_path[PATH_MAX] = "printf";
// 防止上层应用来不及设置日志参数就发生错误，默认输出到工作目录error文件
static char error_path[PATH_MAX]  = "error";
static char mongodb_path[PATH_MAX]  = "mongodb";

// app进程名
static char app_name[LOG_APP_NAME] = {0};

/* 设置日志参数：是否后台，日志路径 */
void set_log_args( bool dm,
    const char *ppath,const char *epath,const char *mpath)
{
    is_daemon = dm;
    snprintf( printf_path,PATH_MAX,"%s",ppath );
    snprintf( error_path ,PATH_MAX,"%s",epath );
    snprintf( mongodb_path ,PATH_MAX,"%s",mpath );
}

/* 设置app进程名 */
void set_app_name( const char *name )
{
#ifdef LOG_APP_NAME
    snprintf( app_name,LOG_APP_NAME,"%s",name );
#endif
}

// print app name，打印app进程名
#ifdef LOG_APP_NAME
    #define PAPPNAME(f) \
        do{ if (app_name[0]) fprintf(f,"[%s]",app_name); } while(0)
#else
    #define PAPPNAME(f)
#endif

// print file time，是否打印文件时间
#ifdef _PFILETIME_
    #define PFILETIME(f,ntm,prefix)                                  \
        fprintf(f, "[%s%02d-%02d %02d:%02d:%02d]",                   \
            prefix,(ntm.tm_mon + 1), ntm.tm_mday,                    \
            ntm.tm_hour, ntm.tm_min,ntm.tm_sec)
#else
    #define PFILETIME(f)
#endif

#define FORMAT_TO_FILE(f)                                           \
    do{                                                             \
        va_list args;                                               \
        va_start(args,fmt);                                         \
        vfprintf(f,fmt,args);                                       \
        va_end(args);                                               \
        fprintf(f,"\n");                                            \
    } while(0)

// 这个本来想写成函数的，但是c++ 03不支持函数之间可变参传递
// 要使用主循环的时间戳，不然服务器卡的时候会造成localtime时间与主循环时间戳不一致
// 查找bug更麻烦
#define RAW_FORMAT( ctm,prefix,path,screen,fmt )                   \
    do{                                                            \
        struct tm ntm;                                             \
        ::localtime_r( &ctm,&ntm );                                \
        if ( screen ){                                             \
            PFILETIME( screen,ntm,prefix );                        \
            PAPPNAME( screen );                                    \
            FORMAT_TO_FILE( screen );                              \
        }                                                          \
        FILE * pf = ::fopen( path, "ab+" );                        \
        if ( !pf ) return;                                         \
        PFILETIME( pf,ntm,prefix );                                \
        FORMAT_TO_FILE( pf );                                      \
        ::fclose( pf );                                            \
    } while(0)

// 错误函数，同步写到文件，用主循环时间戳，线程不安全
void cerror_log( const char *prefix,const char *fmt,... )
{
    time_t tm = static_global::ev()->now();
    RAW_FORMAT( tm,prefix,error_path,(is_daemon ? NULL : stderr),fmt );
}

// 日志打印函数，异步写到文件，用主循环时间戳，线程不安全
void cprintf_log( const char *prefix,const char *fmt,... )
{
    static thread_log *logger = static_global::async_log();

    va_list args;
    va_start(args,fmt);
    logger->raw_write("",LO_CPRINTF,fmt,args);
    va_end(args);
}

// 错误函数，同步写到文件，不用主循环时间戳，线程安全
void raw_cerror_log( time_t tm,const char *prefix,const char *fmt,... )
{
    RAW_FORMAT( tm,prefix,error_path,(is_daemon ? NULL : stderr),fmt );
}

// 错误函数，同步写到文件，不用主循环时间戳，线程安全
void raw_cprintf_log( time_t tm,const char *prefix,const char *fmt,... )
{
    RAW_FORMAT( tm,prefix,printf_path,(is_daemon ? NULL : stdout),fmt );
}

////////////////////////////////////////////////////////////////////////////////

// 单次写入的日志内容
class log_one
{
public:
    log_one(){};
    virtual ~log_one(){};

    time_t _tm;
    size_t _len;
    log_out_t _out;
    char _path[LOG_PATH_MAX]; // TODO:这个路径是不是可以短一点，好占内存

    virtual log::log_size_t get_type() const = 0;
    virtual const char *get_ctx() const = 0;
    virtual void set_ctx( const char *ctx,size_t len ) = 0;
};

template<log::log_size_t lst,size_t size>
class log_one_ctx : public log_one
{
public:
    log::log_size_t get_type() const { return lst; }
    const char *get_ctx() const { return _context; }

    void set_ctx( const char *ctx,size_t len )
    {
        size_t sz = len > size ? size : len;

        _len = sz;
        memcpy( _context,ctx,sz );
        _context[len] = 0; // 有可能是输出到stdout的，必须0结尾
    }
private:
    char _context[size];
};

log::log()
    : _ctx_pool 
    {
        new object_pool< log_one_ctx<LOG_SIZE_S,LOG_CTX_SIZE[0]>,1024,64 >("log_S"),
        new object_pool< log_one_ctx<LOG_SIZE_M,LOG_CTX_SIZE[1]>,1024,64 >("log_M"),
        new object_pool< log_one_ctx<LOG_SIZE_L,LOG_CTX_SIZE[2]>,8,8 >("log_L")
    }
{
    _cache = new log_one_list_t();
    _flush = new log_one_list_t();
}

log::~log()
{
    assert( "log not flush",_cache->empty() && _flush->empty() );

    delete _cache;
    delete _flush;

    _cache = NULL;
    _flush = NULL;

    for ( int idx = 0;idx < LOG_SIZE_MAX;++idx )
    {
        _ctx_pool[idx]->purge();

        delete _ctx_pool[idx];
        _ctx_pool[idx] = NULL;
    }
}

// 等待处理的日志数量
size_t log::pending_size()
{
    return _cache->size() + _flush->size();
}

// 交换缓存和待写入队列
bool log::swap()
{
    if (!_flush->empty() ) return false;

    log_one_list_t *swap_tmp = _flush;
    _flush = _cache;
    _cache = swap_tmp;

    return true;
}

// 主线程写入缓存，上层加锁
int32 log::write_cache( time_t tm,
    const char *path,const char *ctx,size_t len,log_out_t out )
{
    assert( "write log no file path",path );

    class log_one *one = allocate_one( len + 1 );
    if ( !one )
    {
        ERROR( "log write cant not allocate memory" );
        return -1;
    }

    one->_tm = tm;
    one->_out = out;
    one->set_ctx( ctx,len );
    snprintf( one->_path,LOG_PATH_MAX,"%s",path );

    _cache->push_back( one );
    return 0;
}

// 写入一项日志内容
int32 log::flush_one_ctx(
    FILE *pf,const struct log_one *one,struct tm &ntm,const char *prefix )
{
    int byte = PFILETIME(pf,ntm,prefix);

    if ( byte <= 0 )
    {
        ERROR( "log file write time error" );
        return -1;
    }

    size_t wbyte = fwrite(
        (const void*)one->get_ctx(),sizeof(char),one->_len,pf );
    if ( wbyte <= 0 )
    {
        ERROR( "log file write context error" );
        return -1;
    }

    /* 自动换行 */
    static const char * tail = "\n";
    size_t tbyte = fwrite( tail,1,strlen( tail ),pf );
    if ( tbyte <= 0 )
    {
        ERROR( "log file write context error" );
        return -1;
    }

    return 0;
}

// 写入一个日志文件
bool log::flush_one_file(
    struct tm &ntm,const log_one *one,const char *path,const char *prefix )
{
    FILE *pf = _files[path];
    if (!pf)
    {
        pf = fopen( path, "ab+" );
        _files[path] = pf;
    }

    if ( !pf )  /* 无法打开文件*/
    {
        ERROR_R( "can't open log file(%s):%s\n", path,strerror(errno) );

        // TODO:这个异常处理有问题
        // 打开不了文件，可能是权限、路径、磁盘满，这里先全部标识为已写入，丢日志
        return false;
    }

    flush_one_ctx( pf,one,ntm,prefix );

    return true;
}

// 日志线程写入文件
void log::flush()
{
#define FORMAT_TO_SCREEN(screen,ntm,prefix,ctx)                \
    do{                                                        \
        PFILETIME( screen,ntm,prefix );                        \
        PAPPNAME( screen );                                    \
        fprintf(screen,"%s\n",ctx);                            \
    } while(0)

    log_one_list_t::iterator itr = _flush->begin();
    for ( ;itr != _flush->end(); ++itr )
    {
        log_one *one = *itr;
        if ( 0 == one->_len ) continue;

        struct tm ntm;
        localtime_r( &(one->_tm),&ntm );

        switch( one->_out )
        {
            case LO_FILE :
                flush_one_file( ntm,one,one->_path,"" );
                break;
            case LO_LPRINTF :
                flush_one_file( ntm,one,printf_path,"LP" );
                if (!is_daemon)
                {
                    FORMAT_TO_SCREEN( stdout,ntm,"LP",one->get_ctx() );
                }
                break;
            case LO_MONGODB :
                flush_one_file( ntm,one,mongodb_path,"" );
                break;
            case LO_CPRINTF :
                flush_one_file( ntm,one,printf_path,"CP" );
                if (!is_daemon)
                {
                    FORMAT_TO_SCREEN( stdout,ntm,"CP",one->get_ctx() );
                }
                break;
            default:
                ERROR("unknow log output type:%d",one->_out);
                break;

        }

        one->_len = 0;
    }
#undef FORMAT_TO_SCREEN
}

// 回收内存到内存池，上层加锁
void log::collect_mem()
{
    log_one_list_t::iterator itr = _flush->begin();
    for ( ;itr != _flush->end(); ++itr )
    {
        deallocate_one( *itr );
    }

    _flush->clear();
}

// 根据长度从内存池中分配一个日志缓存对象
class log_one *log::allocate_one( size_t len )
{
    if ( len > LOG_MAX_LENGTH ) len = LOG_MAX_LENGTH;

    for ( uint32 lt = LOG_SIZE_S;lt < LOG_SIZE_MAX;++lt )
    {
        if ( len > LOG_CTX_SIZE[lt] ) continue;

        return (log_one*)_ctx_pool[lt]->construct_any();
    }
    return NULL;
}

//回收一个日志缓存对象到内存池
void log::deallocate_one( class log_one *one )
{
    assert( "deallocate one NULL log ctx",one );

    log_size_t lt = one->get_type();

    _ctx_pool[lt]->destroy_any( one );
}

void log::close_files()
{
    // 暂时保留文件名，以免频繁创建，应该也不是很多
    map_t<std::string,FILE *>::iterator itr = _files.begin();
    while ( itr != _files.end() )
    {
        FILE *pf = itr->second;
        if (pf)
        {
            ::fclose(pf);
            itr->second = NULL;
        }

        itr ++;
    }
}
