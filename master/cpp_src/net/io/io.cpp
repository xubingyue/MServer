#include "io.h"

io::io( class buffer *recv,class buffer *send )
{
    _fd = -1; // 创建一个io的时候，fd可能还未创建，后面再设置
    _recv = recv;
    _send = send;
}

io::~io()
{
    _fd = -1;
    _recv = NULL;
    _send = NULL;
}

// 返回: < 0 错误，0 成功，1 需要重读，2 需要重写
int32 io::recv( int32 &byte )
{
    assert( "io recv fd invalid",_fd > 0 );

    byte = 0;
    if ( !_recv->reserved() ) return -1; /* no more memory */

    // epoll当前为LT模式，不用循环读。一般来说缓冲区都分配得比较大，都能读完
    uint32 size = _recv->get_space_size();
    int32 len = ::read( _fd,_recv->get_space_ctx(),size );
    if ( expect_true(len > 0) )
    {
        byte = len;
        _recv->add_used_offset( len );
        return 0;
    }

    if ( 0 == len ) return -1; // 对方主动断开

    /* error happen */
    if ( errno != EAGAIN && errno != EWOULDBLOCK )
    {
        ERROR( "io send:%s",strerror(errno) );
        return -1;
    }

    return 1; // 重试
}

// * 返回: < 0 错误，0 成功，1 需要重读，2 需要重写
int32 io::send( int32 &byte )
{
    assert( "io send fd invalid",_fd > 0 );

    byte = 0;
    size_t bytes = _send->get_used_size();
    assert( "io send without data",bytes > 0 );

    int32 len = ::write( _fd,_send->get_used_ctx(),bytes );

    if ( expect_true(len > 0) )
    {
        byte = len;
        _send->remove( len );
        return 0 == _send->get_used_size() ? 0 : 2;
    }

    if ( 0 == len ) return -1;// 对方主动断开

    /* error happen */
    if ( errno != EAGAIN && errno != EWOULDBLOCK )
    {
        ERROR( "io send:%s",strerror(errno) );
        return -1;
    }

    /* need to try again */
    return 2;
}
