/* a star寻路算法
 * 2018-07-18 by xzc
 * http://theory.stanford.edu/~amitp/GameProgramming/
 * https://www.geeksforgeeks.org/a-search-algorithm/
 */

 #ifndef __A_STAR_H__
 #define __A_STAR_H__

#include <vector>
#include "../pool/object_pool.h"

class grid_map;
class a_star
{
public:
    // 路径辅助节点
    struct node
    {
        uint8 mask; // 是否close
        int32 g; // a*算法中f = g + h中的g，代表从起始位置到该格子的开销
        int32 h; // a*算法中f = g + h中的h，代表该格子到目标节点预估的开销
        uint16 x; // 该格子的x坐标
        uint16 y; // 该格子的y坐标
        uint16 px; // 该格子的父格子x坐标
        uint16 py; // 该格子的父格子y坐标
    };
public:
    a_star();
    ~a_star();
    /* 搜索路径
     * @map：对应地图的地形数据
     * @x,y：起点坐标
     * @dx,dy：dest，终点坐标
     */
    bool search( const grid_map *map,int32 x,int32 y,int32 dx,int32 dy);
    // 获取路径
    const std::vector<uint16> &get_path() const { return _path; }
private:
    struct node *pop_open_set();
    bool backtrace_path(
        const struct node *dest,int32 dx,int32 dy,uint16 height );
    bool do_search(
        const grid_map *map,int32 x,int32 y,int32 dx,int32 dy);
    struct node *new_node(uint16 x,uint16 y,uint16 px = 0,uint16 py = 0);

    /* 启发函数的选择，下面的连接说明各个算法的适用场景及效率
     * http://theory.stanford.edu/~amitp/GameProgramming/Heuristics.html
     * f = g + h中，g和h的值应该是要匹配的。比如两者都是坐标距离
     * h = 0，则变成Dijkstra算法，能保证最短路径
     * h < n，n表示当前点到目标点的实际距离，能保证最短路径，只是会多搜索一些格子
     * h = n，则是最理想的情况，每次都搜索到最合适的格子
     * h > n，无法保证最短路径
     * h >> g,即h远大于g，相当于g为0，则算法变为Greedy Best-First-Search
     */

    /* 曼哈顿距离，不会算对角距离，
     * 适用只能往东南西北4个方向，不能走对角的游戏
     */
    int32 manhattan(int32 x,int32 y,int32 gx,int32 gy);

    /* 对角距离
     * 适用东南西北，以及东北-东南-西南-西北(沿45度角走)的游戏
     */
    int32 diagonal(int32 x,int32 y,int32 gx,int32 gy);

    /* 欧几里得距离
     * 适用可以沿任意角度行走的游戏。但是f = g + h中，g的值是一步步算出来的，因此g值
     * 要么是直线，要么是45度角的消耗，因此会导致f值不准确。不过这里的h <= n，还是可以
     * 得到最小路径，只是算法效率受影响
     */
    int32 euclidean(int32 x,int32 y,int32 gx,int32 gy);
private:
    struct node **_node_set; // 记录当前寻路格子集合
    struct node *_node_pool; // 格子对象内存池
    std::vector<uint16> _path; // 生成的路径，反向并且每两个元素表示一个格子
    std::vector<struct node*> _open_set; // 记录算法运行过程中待处理的格子

    int32 _set_max;  // 当前集合大小
    int32 _pool_max; // 内存池格子数量
    int32 _pool_idx; // 内存池当前已用数量
};

#endif /* __A_STAR_H__ */
