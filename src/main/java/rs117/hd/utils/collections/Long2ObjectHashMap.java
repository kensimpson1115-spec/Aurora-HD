package rs117.hd.utils.collections;

import static rs117.hd.utils.collections.Util.murmurHash3;

/**
 * Small allocation-free primitive long -> object hash map for hot render-frame caches.
 *
 * <p>This intentionally implements only the operations Aurora needs for per-frame
 * model batching: get, put, clear and size. A null value marks an empty slot, so
 * null values are not supported. Clear touches only slots used in the current
 * frame rather than wiping the whole backing array.</p>
 */
public final class Long2ObjectHashMap<T>
{
    private static final float LOAD_FACTOR = 0.65f;
    private static final int MIN_CAPACITY = 16;

    private long[] keys;
    private Object[] values;
    private int[] touchedSlots;
    private int touchedCount;
    private int size;
    private int mask;

    public Long2ObjectHashMap()
    {
        this(MIN_CAPACITY);
    }

    public Long2ObjectHashMap(int initialCapacity)
    {
        int capacity = MIN_CAPACITY;
        while (capacity < initialCapacity)
            capacity <<= 1;
        allocate(capacity);
    }

    private void allocate(int capacity)
    {
        keys = new long[capacity];
        values = new Object[capacity];
        touchedSlots = new int[capacity];
        mask = capacity - 1;
        touchedCount = 0;
        size = 0;
    }

    @SuppressWarnings("unchecked")
    public T get(long key)
    {
        int index = indexFor(key);
        while (true)
        {
            Object value = values[index];
            if (value == null)
                return null;
            if (keys[index] == key)
                return (T) value;
            index = (index + 1) & mask;
        }
    }

    public void put(long key, T value)
    {
        if (value == null)
            throw new IllegalArgumentException("Long2ObjectHashMap does not support null values");

        if (size + 1 > (int) (values.length * LOAD_FACTOR))
            grow();

        putNoGrow(key, value);
    }

    private void putNoGrow(long key, T value)
    {
        int index = indexFor(key);
        while (true)
        {
            Object existing = values[index];
            if (existing == null)
            {
                keys[index] = key;
                values[index] = value;
                touchedSlots[touchedCount++] = index;
                size++;
                return;
            }
            if (keys[index] == key)
            {
                values[index] = value;
                return;
            }
            index = (index + 1) & mask;
        }
    }

    private int indexFor(long key)
    {
        long hash = murmurHash3(key);
        return (int) (hash ^ (hash >>> 32)) & mask;
    }

    private void grow()
    {
        long[] oldKeys = keys;
        Object[] oldValues = values;
        int[] oldTouched = touchedSlots;
        int oldTouchedCount = touchedCount;

        allocate(values.length << 1);

        for (int i = 0; i < oldTouchedCount; i++)
        {
            int slot = oldTouched[i];
            Object value = oldValues[slot];
            if (value != null)
            {
                @SuppressWarnings("unchecked")
                T typedValue = (T) value;
                putNoGrow(oldKeys[slot], typedValue);
            }
        }
    }

    public void clear()
    {
        for (int i = 0; i < touchedCount; i++)
            values[touchedSlots[i]] = null;
        touchedCount = 0;
        size = 0;
    }

    public int size()
    {
        return size;
    }

    public int capacity()
    {
        return values.length;
    }
}
