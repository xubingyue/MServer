#include "ltools.h"
#include "lgrid_aoi.h"

lgrid_aoi::~lgrid_aoi()
{
}

lgrid_aoi::lgrid_aoi( lua_State *L )
{
}

int32 lgrid_aoi::set_watch_mask( lua_State *L ) // 设置需要放入watch_me列表的实体类型
{
    int32 mask = luaL_checkinteger(L,1);
    grid_aoi::set_watch_mask(mask);

    return 0;
}

int32 lgrid_aoi::set_visual_range( lua_State *L ) // 设置视野
{
    // 这里的宽高都是指格子数
    int32 width = luaL_checkinteger(L,1);
    int32 height = luaL_checkinteger(L,2);
    grid_aoi::set_visual_range(width,height);

    return 0;
}

int32 lgrid_aoi::set_size( lua_State *L ) // 设置宽高，格子像素
{
    // 这里的宽高都是指像素，因为地图的大小可能并不刚好符合格子数，后面再做转换
    int32 width = luaL_checkinteger(L,1);
    int32 height = luaL_checkinteger(L,2);
    int32 pix = luaL_checkinteger(L,3);
    grid_aoi::set_size(width,height,pix);

    return 0;
}

// 获取某个类型的实体
int32 lgrid_aoi::get_all_entitys(lua_State *L)
{
    // 可以多个实体类型，按位表示
    int32 mask = luaL_checkinteger(L,1);

    lUAL_CHECKTABLE(L,2); // 用来保存返回的实体id的table

    int32 index = 1;
    entity_set_t::const_iterator itr = _entity_set.begin();
    for (;itr != _entity_set.end();itr ++)
    {
        const grid_aoi::entity_ctx *ctx = itr->second;
        if (ctx && (ctx->_type & mask))
        {
            lua_pushinteger(L,ctx->_id);
            lua_rawseti(L,2,index);

            index ++;
        }
    }

    // 类似table.pack的做法，最后设置一个n表示数量
    lua_pushstring( L,"n" );
    lua_pushinteger(L,index - 1);
    lua_rawset(L,2);

    lua_pushinteger(index - 1);
    return 1;
}

/* 获取某一范围内实体
 * 底层这里只支持矩形，如果是其他形状的，上层根据实体位置再筛选即可
 */
int32 lgrid_aoi::get_entitys( lua_State *L )
{
    // 可以多个实体类型，按位表示
    int32 mask = luaL_checkinteger(L,1);

    lUAL_CHECKTABLE(L,2);

    // 矩形的两个对角像素坐标
    int32 srcx = luaL_checkinteger(L,3);
    int32 srcy = luaL_checkinteger(L,4);
    int32 destx = luaL_checkinteger(L,5);
    int32 desty = luaL_checkinteger(L,6);

    entity_vector_t *list = new_entity_vector();
    if (grid_aoi::get_entitys(list,srcx,srcy,destx,desty) < 0)
    {
        return luaL_error(L,"aoi entitys error");
    }

    return 0;
}

int32 lgrid_aoi::exit_entity( lua_State *L )
{
    return 0;
}

int32 lgrid_aoi::enter_entity( lua_State *L )
{
    return 0;
}

int32 lgrid_aoi::update_entity( lua_State *L )
{
    return 0;
}
