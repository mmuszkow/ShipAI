/**
 * An AyStar implementation.
 *  It solves graphs by finding the fastest route from one point to the other.
 *
 * This is a copy of Graph.AyStar class with the following changes:
 * - CheckDirection was removed (it was unused)
 * - each Path item has the infrastructure attribute
 * - getters for Path were replaced with direct attributes
 * - single source & goal
 * - ignored tiles are AIList instead of array
 * - "native" heap is used instead of binary heap
 */

/* Simply using AIList of indexes is faster than any squirrel implementation. */
class NativeHeap {
    _data = null;
    _sorter = null;
    _size = null;

    constructor() {
        this._data = [];
        this._sorter = AIList();
        this._size = 0;
    }

    function Insert(obj, value) {
        _data.push(obj);
        _sorter.AddItem(_data.len() - 1, value);
        _size++;
    }

    function Pop() {
        _sorter.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
        local ret = _data[_sorter.Begin()];
        _sorter.RemoveTop(1);
        _size--;
        return ret;
    }

    function Count() {
        return _size;
    }
};

class AyStar
{
    _pf_instance = null;
    _cost_callback = null;
    _estimate_callback = null;
    _neighbours_callback = null;
    _open = null;
    _closed = null;
    _goal = null;

    /**
     * @param pf_instance An instance that'll be used as 'this' for all
     *  the callback functions.
     * @param cost_callback A function that returns the cost of a path. It
     *  should accept four parameters, old_path, new_tile, new_direction and
     *  cost_callback_param. old_path is an instance of AyStar.Path, and
     *  new_node is the new node that is added to that path. It should return
     *  the cost of the path including new_node.
     * @param estimate_callback A function that returns an estimate from a node
     *  to the goal node. It should accept four parameters, tile, direction,
     *  goal_nodes and estimate_callback_param. It should return an estimate to
     *  the cost from the lowest cost between node and any node out of goal_nodes.
     *  Note that this estimate is not allowed to be higher than the real cost
     *  between node and any of goal_nodes. A lower value is fine, however the
     *  closer it is to the real value, the better the performance.
     * @param neighbours_callback A function that returns all neighbouring nodes
     *  from a given node. It should accept three parameters, current_path, node
     *  and neighbours_callback_param. It should return an array containing all
     *  neighbouring nodes, which are an array in the form [tile, direction].
     */
    constructor(pf_instance, cost_callback, estimate_callback, neighbours_callback)
    {
        if (typeof(pf_instance) != "instance") throw("'pf_instance' has to be an instance.");
        if (typeof(cost_callback) != "function") throw("'cost_callback' has to be a function-pointer.");
        if (typeof(estimate_callback) != "function") throw("'estimate_callback' has to be a function-pointer.");
        if (typeof(neighbours_callback) != "function") throw("'neighbours_callback' has to be a function-pointer.");

        this._pf_instance = pf_instance;
        this._cost_callback = cost_callback;
        this._estimate_callback = estimate_callback;
        this._neighbours_callback = neighbours_callback;
    }

    /**
     * Initialize a path search between source and goal.
     * @param source The source node.
     * @param goal The target tile.
     * @param ignored_tiles An AITileList of tiles that cannot occur in the final path.
     */
    function InitializePath(source, goal, ignored_tiles = AITileList());

    /**
     * Try to find the path as indicated with InitializePath with the lowest cost.
     * @param iterations After how many iterations it should abort for a moment.
     *  This value should either be -1 for infinite, or > 0. Any other value
     *  aborts immediatly and will never find a path.
     * @return A route if one was found, or false if the amount of iterations was
     *  reached, or null if no path was found.
     *  You can call this function over and over as long as it returns false,
     *  which is an indication it is not yet done looking for a route.
     */
    function FindPath(iterations);
};

/* Used to set all directions in ignored tiles to be blocked, see InitializePath. */
function __val__Set0xFF(item) {
    return ~0;
}

function AyStar::InitializePath(source, goal, ignored_tiles = AITileList())
{
    this._open = NativeHeap();
    this._goal = goal;
    this._closed = ignored_tiles;
    this._closed.Valuate(__val__Set0xFF);

    if (source[1] <= 0) throw("directional value should never be zero or negative.");
    local new_path = this.Path(null, source[0], source[1], source[2], this._cost_callback, this._pf_instance);
    this._open.Insert(new_path, new_path.cost + this._estimate_callback(this._pf_instance, source[0], source[1]));
}

function AyStar::FindPath(iterations)
{
    if (this._open == null) throw("can't execute over an uninitialized path");

    while (this._open.Count() > 0 && (iterations == -1 || iterations-- > 0)) {
        /* Get the path with the best score so far */
        local path = this._open.Pop();
        local cur_tile = path.tile;
        /* Make sure we didn't already passed it */
        if (this._closed.HasItem(cur_tile)) {
            /* If the direction is already on the list, skip this entry */
            if ((this._closed.GetValue(cur_tile) & path.direction) != 0) continue;
            /* Add the new direction */
            this._closed.SetValue(cur_tile, this._closed.GetValue(cur_tile) | path.direction);
        } else {
            /* New entry, make sure we don't check it again */
            this._closed.AddItem(cur_tile, path.direction);
        }
        /* Check if we found the end */
        if (cur_tile == this._goal) {
            this._CleanPath();
            return path;
        }
        
        /* Scan all neighbours */
        local neighbours = this._neighbours_callback(this._pf_instance, path, cur_tile);
        foreach (node in neighbours) {
            if (node[1] <= 0) throw("directional value should never be zero or negative.");

            if ((this._closed.GetValue(node[0]) & node[1]) != 0) continue;
            /* Calculate the new paths and add them to the open list */
            local new_path = this.Path(path, node[0], node[1], node[2], this._cost_callback, this._pf_instance);
            this._open.Insert(new_path, new_path.cost + this._estimate_callback(this._pf_instance, node[0], node[1]));
        }
    }

    if (this._open.Count() > 0) return false;
    this._CleanPath();
    return null;
}

function AyStar::_CleanPath()
{
    this._closed = null;
    this._open = null;
    this._goal = null;
}

/**
 * The path of the AyStar algorithm.
 *  It is reversed, that is, the first entry is more close to the goal-nodes
 *  than his parent. You can walk this list to find the whole path.
 *  The last entry has a prev of null.
 */
class AyStar.Path
{
    prev = null;
    tile = null;
    direction = null;
    cost = null;
    length = null;
    infrastructure = null;

    constructor(old_path, new_tile, new_direction, _infrastructure, cost_callback, pf_instance)
    {
        this.prev = old_path;
        this.tile = new_tile;
        this.direction = new_direction;
        this.cost = cost_callback(pf_instance, old_path, new_tile, new_direction);
        if (old_path == null)
            this.length = 0;
        else
            this.length = old_path.length + AIMap.DistanceManhattan(old_path.tile, new_tile);
        this.infrastructure = _infrastructure;
    };
};

