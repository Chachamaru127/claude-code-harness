Add a `getOrSet(key, factory, ttl?)` method to TTLCache.
The interface definition is in `types.ts`.
If the key exists, return its value; otherwise call the factory function, store the result, and return it.
The factory should also support async functions.
