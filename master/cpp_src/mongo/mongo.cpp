#include "mongo.h"

void mongo::init()
{
    mongoc_init();
}

void mongo::cleanup()
{
    mongoc_cleanup();
}

mongo::mongo()
{
    _conn = NULL;
}

mongo::~mongo()
{
    assert( "mongo db not clean yet",NULL == _conn );
}

void mongo::set( const char *ip,
    const int32 port,const char *usr,const char *pwd,const char *db )
{
    /* 将数据复制一份，允许上层释放对应的内存 */
    _port = port;
    snprintf( _ip ,MONGO_VAR_LEN,"%s",ip  );
    snprintf( _usr,MONGO_VAR_LEN,"%s",usr );
    snprintf( _pwd,MONGO_VAR_LEN,"%s",pwd );
    snprintf( _db ,MONGO_VAR_LEN,"%s",db  );
}

int32 mongo::connect()
{
    assert( "mongo duplicate connect",!_conn );

    char uri[PATH_MAX];
    /* "mongodb://user:password@localhost/?authSource=mydb" */
    snprintf( uri,PATH_MAX,
        "mongodb://%s:%s@%s:%d/?authSource=%s",_usr,_pwd,_ip,_port,_db );
    _conn = mongoc_client_new( uri );
    if ( !_conn )
    {
        ERROR( "parse mongo uri fail\n" );
        return 1;
    }

    /* mongoc_client_new只是创建一个对象，并没有connect,ping保证连接通畅
     * 默认10s超时.超服时阻塞,应该可以接受.尝试ping一下，失败也不一定说明有问题
     * 需要关注日志。
     */
    int32 ok = ping();
    return 0 == ok ? 0 : -1;
}

void mongo::disconnect()
{
    if ( _conn ) mongoc_client_destroy( _conn );
    _conn = NULL;
}

int32 mongo::ping()
{
    assert( "try to ping a inactive mongo",_conn );

    bson_t ping;
    bson_init( &ping );
    bson_append_int32( &ping, "ping", -1, 1 );
    mongoc_database_t * database = mongoc_client_get_database( _conn, _db );

    /* cursor总是需要释放 */
    mongoc_cursor_t *cursor = mongoc_database_command(
        database,(mongoc_query_flags_t)0, 0, 1, 0, &ping, NULL, NULL );

    const bson_t *reply;
    if ( mongoc_cursor_next( cursor, &reply ) )
    {
        mongoc_cursor_destroy( cursor );
        bson_destroy( &ping );

        mongoc_database_destroy( database );
        return 0;
    }

    /* get the error */
    bson_error_t error;
    int32 ecode = mongoc_cursor_error( cursor, &error );
    if ( ecode )
    {
        ERROR_R( "mongo ping error(%d):%s",error.code,error.message );
    }

    mongoc_cursor_destroy( cursor );
    bson_destroy( &ping );
    mongoc_database_destroy( database );

   return ecode;
}

bool mongo::count( const struct mongo_query *mq,struct mongo_result *res )
{
    assert( "mongo count,inactivity connection",_conn );
    assert( "mongo count,empty query",mq );

    mongoc_collection_t *collection =
        mongoc_client_get_collection( _conn, _db, mq->_clt );

    // opts = {"skip":1,"limit":5}
    int64 count = mongoc_collection_count_documents(
        collection,mq->_query,mq->_opts,NULL,NULL,&res->_error );

    mongoc_collection_destroy ( collection );

    if ( count < 0 )    /* 如果失败，返回-1 */
    {
        res->_data  = NULL;

        return false;
    }

    bson_t *doc = bson_new();
    BSON_APPEND_INT64( doc,"count",count );

    res->_data  = doc;

    return true;
}

bool mongo::find ( const struct mongo_query *mq,struct mongo_result *res )
{
    assert( "mongo find,inactivity connection",_conn );
    assert( "mongo find,empty query",mq );

    mongoc_collection_t *collection =
        mongoc_client_get_collection( _conn, _db, mq->_clt );

    mongoc_cursor_t *cursor =
        mongoc_collection_find_with_opts(
        collection, mq->_query, mq->_fields, NULL );

    int32 index = 0;
    bson_t *doc = bson_new();

    const bson_t *sub_doc = NULL;
    while ( mongoc_cursor_next( cursor, &sub_doc ) )
    {
        /* The bson objects set in this function are ephemeral and good until
         * the next call. This means that you must copy the returned bson if you
         * wish to retain it beyond the lifetime of a single call to
         * mongoc_cursor_next()
         * bson_append_document内部使用memcpy做了内存拷贝,无需使用bson_copy
         * 对bson，array、document是一样的，只是前者的key必须为0 1 2 ...,使用
         * bson_append_document还是bson_append_array仅在bson_iter_type中有区别
         */

        const int32 buff_len = 128;
        char index_buff[buff_len];
        snprintf( index_buff,buff_len,"%d",index );

        bool r = BSON_APPEND_DOCUMENT( doc,index_buff,sub_doc );
        index ++;

        assert( "bson append document err",r );
    }

    if ( mongoc_cursor_error( cursor,&res->_error ) )
    {
        ERROR_R("mongoc_cursor_error");
        bson_destroy( doc );
        res->_data  = NULL;

        mongoc_collection_destroy ( collection );
        return false;
    }

    res->_data  = doc;

    mongoc_cursor_destroy( cursor );
    mongoc_collection_destroy ( collection );

    return true;
}

bool mongo::find_and_modify (
    const struct mongo_query *mq,struct mongo_result *res )
{
    assert( "mongo find_and_modify,inactivity connection",_conn );
    assert( "mongo find_and_modify,empty query",mq );

    mongoc_collection_t *collection =
        mongoc_client_get_collection( _conn, _db, mq->_clt );

    assert( "mongo find_and modify data dirty",NULL == res->_data );

    res->_data = bson_new();
    bool ok = mongoc_collection_find_and_modify(
        collection,mq->_query,mq->_sort,mq->_update,
        mq->_fields,mq->_remove,mq->_upsert,mq->_new,res->_data,&res->_error );

    mongoc_collection_destroy ( collection );
    if ( !ok )
    {
        bson_destroy( res->_data );
        res->_data  = NULL      ;

        return false;

    }

    return true;
}

bool mongo::insert( const struct mongo_query *mq,struct mongo_result *res )
{
    assert( "mongo insert,inactivity connection",_conn );
    assert( "mongo insert,empty query",mq );

    mongoc_collection_t *collection =
        mongoc_client_get_collection( _conn, _db, mq->_clt );

    bool ok = mongoc_collection_insert(
        collection, MONGOC_INSERT_NONE, mq->_query, NULL, &res->_error );

    mongoc_collection_destroy ( collection );

    return ok;
}

bool mongo::update( const struct mongo_query *mq,struct mongo_result *res )
{
    assert( "mongo update,inactivity connection",_conn );
    assert( "mongo update,empty query",mq );

    mongoc_collection_t *collection =
        mongoc_client_get_collection( _conn, _db, mq->_clt );

    mongoc_update_flags_t flags = (mongoc_update_flags_t)mq->_flags;

    bool ok = mongoc_collection_update(
        collection, flags, mq->_query, mq->_update, NULL, &res->_error );

    mongoc_collection_destroy ( collection );

    return ok;
}

bool mongo::remove( const struct mongo_query *mq,struct mongo_result *res )
{
    assert( "mongo remove,inactivity connection",_conn );
    assert( "mongo remove,empty query",mq );

    mongoc_collection_t *collection =
        mongoc_client_get_collection( _conn, _db, mq->_clt );

    bool ok = mongoc_collection_remove( collection,
        (mongoc_remove_flags_t)mq->_flags, mq->_query, NULL, &res->_error );

    mongoc_collection_destroy ( collection );

    return ok;
}
