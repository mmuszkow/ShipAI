/* Hashset that stores integers or integer pairs. */
class HashSet {
    _data = [];
    _size = 0;
    
    constructor(size) {
        _data = array(size);
        _size = size;
    }
}

/* Modulo. */
function HashSet::Hash(val) {
    local hash = val % this._size;
    return hash < 0 ? hash + this._size : hash;
}

/* Cantor pairing function. */
function HashSet::HashPair(val1, val2) {
    local hash = ((((val1 + val2) * (val1 + val2 + 1)) >> 1) + val2) % this._size;
    return hash < 0 ? hash + this._size : hash;
}

function HashSet::Add(val) {
    local hash = Hash(val);
    if(this._data[hash] == null)
        this._data[hash] = [];
    this._data[hash].append(val);
}

/* Add integers pair. */
function HashSet::AddPair(val1, val2) {
    local hash = HashPair(val1, val2);
    if(this._data[hash] == null)
        this._data[hash] = [];
    this._data[hash].append([val1, val2]);
}

function HashSet::Contains(val) {
    local hash = Hash(val);
    if(this._data[hash] == null)
        return false;
    for(local i = 0; i < this._data[hash].len(); i++) {
        if(this._data[hash][i] == val)
            return true;
    }
    return false;
}

function HashSet::_ContainsPair(val1, val2) {
    local hash = HashPair(val1, val2);
    if(this._data[hash] == null)
        return false;
    for(local i = 0; i < this._data[hash].len(); i++) {
        if(this._data[hash][i][0] == val1 && this._data[hash][i][1] == val2)
            return true;
    }
    return false;
}

function HashSet::ContainsPair(val1, val2) {
    return _ContainsPair(val1, val2) || _ContainsPair(val2, val1);
}

function HashSet::Debug() {
    local non_zero = 0;
    local sum = 0;
    local maxx = 0;
    for(local i = 0; i < this._size; i++)
        if(this._data[i] != null) {
            non_zero++;
            sum += this._data[i].len();
            maxx = max(maxx, this._data[i].len());
        }
    if(non_zero > 0)
        AILog.Info("HashSet size=" + this._size + " non_zero=" + non_zero + " avg. len=" + (sum / non_zero) + " max=" + maxx);
}
