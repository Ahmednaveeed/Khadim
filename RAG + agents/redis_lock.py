# redis_lock.py
"""
Distributed Locking Module for Agent Conflict Resolution

Provides Redis-based distributed locks to prevent race conditions when:
- Multiple users modify the same cart simultaneously
- Competing chef assignments occur
- Order placement needs to be atomic

Uses Redis SETNX (SET if Not eXists) with automatic expiry for safety.
"""

import time
import uuid
from typing import Optional
from redis_connection import RedisConnection


class RedisLock:
    """
    Distributed lock implementation using Redis.
    
    Features:
    - Atomic lock acquisition with SETNX
    - Automatic expiry to prevent deadlocks
    - Owner tracking to prevent accidental release by wrong process
    - Retry mechanism for lock acquisition
    """
    
    # Lock prefixes for different resources
    LOCK_PREFIX_CART = "lock:cart:"
    LOCK_PREFIX_ORDER = "lock:order:"
    LOCK_PREFIX_CHEF = "lock:chef:"
    
    def __init__(self):
        self.redis = RedisConnection.get_instance()
        self._owner_id = str(uuid.uuid4())  # Unique ID for this lock holder
    
    # =========================================================
    #   CART LOCKS
    # =========================================================
    
    def acquire_cart_lock(self, cart_id: str, timeout: int = 5, retry_count: int = 3, retry_delay: float = 0.1) -> bool:
        """
        Acquire a lock on a cart to prevent concurrent modifications.
        
        Args:
            cart_id: The cart ID to lock
            timeout: Lock expiry time in seconds (prevents deadlocks)
            retry_count: Number of times to retry if lock is held
            retry_delay: Seconds to wait between retries
            
        Returns:
            True if lock acquired, False otherwise
        """
        lock_key = f"{self.LOCK_PREFIX_CART}{cart_id}"
        lock_value = f"{self._owner_id}:{time.time()}"
        
        for attempt in range(retry_count):
            # SETNX with expiry - atomic operation
            acquired = self.redis.set(lock_key, lock_value, nx=True, ex=timeout)
            
            if acquired:
                print(f"[RedisLock] ✅ Acquired cart lock: {cart_id}")
                return True
            
            if attempt < retry_count - 1:
                time.sleep(retry_delay)
        
        print(f"[RedisLock] ❌ Failed to acquire cart lock: {cart_id} (held by another process)")
        return False
    
    def release_cart_lock(self, cart_id: str) -> bool:
        """
        Release a cart lock. Only releases if we own the lock.
        
        Returns:
            True if released, False if lock didn't exist or wasn't ours
        """
        lock_key = f"{self.LOCK_PREFIX_CART}{cart_id}"
        
        # Check if we own the lock before releasing
        current_value = self.redis.get(lock_key)
        if current_value and current_value.startswith(self._owner_id):
            self.redis.delete(lock_key)
            print(f"[RedisLock] 🔓 Released cart lock: {cart_id}")
            return True
        
        return False
    
    def is_cart_locked(self, cart_id: str) -> bool:
        """Check if a cart is currently locked."""
        lock_key = f"{self.LOCK_PREFIX_CART}{cart_id}"
        return self.redis.exists(lock_key) > 0
    
    # =========================================================
    #   ORDER LOCKS (for atomic order processing)
    # =========================================================
    
    def acquire_order_lock(self, order_id: int, timeout: int = 30) -> bool:
        """
        Acquire a lock on an order for atomic processing.
        Longer timeout since order processing involves multiple agents.
        """
        lock_key = f"{self.LOCK_PREFIX_ORDER}{order_id}"
        lock_value = f"{self._owner_id}:{time.time()}"
        
        acquired = self.redis.set(lock_key, lock_value, nx=True, ex=timeout)
        if acquired:
            print(f"[RedisLock] ✅ Acquired order lock: {order_id}")
        return bool(acquired)
    
    def release_order_lock(self, order_id: int) -> bool:
        """Release an order lock."""
        lock_key = f"{self.LOCK_PREFIX_ORDER}{order_id}"
        current_value = self.redis.get(lock_key)
        if current_value and current_value.startswith(self._owner_id):
            self.redis.delete(lock_key)
            print(f"[RedisLock] 🔓 Released order lock: {order_id}")
            return True
        return False
    
    # =========================================================
    #   CHEF LOCKS (for exclusive chef assignment)
    # =========================================================
    
    def acquire_chef_lock(self, chef_name: str, timeout: int = 2) -> bool:
        """
        Briefly lock a chef during task assignment to prevent double-booking.
        Short timeout since chef assignment is quick.
        """
        lock_key = f"{self.LOCK_PREFIX_CHEF}{chef_name}"
        lock_value = f"{self._owner_id}:{time.time()}"
        
        acquired = self.redis.set(lock_key, lock_value, nx=True, ex=timeout)
        return bool(acquired)
    
    def release_chef_lock(self, chef_name: str) -> bool:
        """Release a chef lock."""
        lock_key = f"{self.LOCK_PREFIX_CHEF}{chef_name}"
        current_value = self.redis.get(lock_key)
        if current_value and current_value.startswith(self._owner_id):
            self.redis.delete(lock_key)
            return True
        return False


class IdempotencyManager:
    """
    Manages idempotency keys to prevent duplicate operations.
    
    When a request is processed:
    1. Check if idempotency_key exists in Redis
    2. If yes, return cached result (duplicate request)
    3. If no, process request and cache result
    """
    
    IDEMPOTENCY_PREFIX = "idempotent:"
    DEFAULT_TTL = 3600  # 1 hour
    
    def __init__(self):
        self.redis = RedisConnection.get_instance()
    
    def check_and_get_cached(self, idempotency_key: str) -> Optional[dict]:
        """
        Check if this request was already processed.
        
        Returns:
            Cached result if duplicate, None if new request
        """
        if not idempotency_key:
            return None
            
        cache_key = f"{self.IDEMPOTENCY_PREFIX}{idempotency_key}"
        cached = self.redis.get(cache_key)
        
        if cached:
            import json
            print(f"[Idempotency] ⚠️ Duplicate request detected: {idempotency_key}")
            return json.loads(cached)
        
        return None
    
    def cache_result(self, idempotency_key: str, result: dict, ttl: int = None) -> None:
        """
        Cache the result of a processed request.
        
        Args:
            idempotency_key: Unique key for this request
            result: The result to cache
            ttl: Time to live in seconds (default 1 hour)
        """
        if not idempotency_key:
            return
            
        import json
        cache_key = f"{self.IDEMPOTENCY_PREFIX}{idempotency_key}"
        self.redis.setex(cache_key, ttl or self.DEFAULT_TTL, json.dumps(result))
        print(f"[Idempotency] 📝 Cached result for: {idempotency_key}")
    
    def generate_key(self, agent: str, command: str, payload_hash: str) -> str:
        """Generate a deterministic idempotency key from request components."""
        import hashlib
        combined = f"{agent}:{command}:{payload_hash}"
        return hashlib.sha256(combined.encode()).hexdigest()[:16]


# Singleton instances for easy import
_lock_instance = None
_idempotency_instance = None

def get_lock_manager() -> RedisLock:
    """Get singleton RedisLock instance."""
    global _lock_instance
    if _lock_instance is None:
        _lock_instance = RedisLock()
    return _lock_instance

def get_idempotency_manager() -> IdempotencyManager:
    """Get singleton IdempotencyManager instance."""
    global _idempotency_instance
    if _idempotency_instance is None:
        _idempotency_instance = IdempotencyManager()
    return _idempotency_instance
