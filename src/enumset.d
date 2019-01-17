import std.algorithm.comparison;

template EnumSet(E) {
  struct EnumSet {
    bool[] flags;
    this(E value, E[] values...) {
      E m = value;
      foreach (val; values) {
        m = max(m, val);
      }
      flags.length = cast(int) m + 1;
      flags[cast(int) value] = true;
      foreach (val; values) {
        flags[cast(int) val] = true;
      }
    }

    bool contains(E value) const {
      auto k = cast(int) value;
      return k < flags.length && flags[k];
    }

    void add(E value) {
      auto k = cast(int) value;
      if (k >= flags.length)
        flags.length = k + 1;
      flags[k] = true;
    }

    void remove(E value) {
      auto k = cast(int) value;
      if (k < flags.length)
        flags[k] = false;
    }
  }
}
