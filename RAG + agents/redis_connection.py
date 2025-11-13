# redis_connection.py
import redis
import os

class RedisConnection:
    """Singleton Redis connection class."""
    
    _instance = None
    
    @classmethod
    def get_instance(cls):
        """Get the singleton Redis connection instance."""
        if cls._instance is None:
            cls._instance = cls._create_instance()
        return cls._instance

    @staticmethod
    def _create_instance():
        """Creates and tests a new Redis connection."""
        try:
            # We are using 127.0.0.1 directly to avoid any localhost resolution
            # issues that can be caused by firewalls.
            r = redis.Redis(
                host=os.getenv('REDIS_HOST', '127.0.0.1'),
                port=int(os.getenv('REDIS_PORT', 6379)),
                db=0,
                decode_responses=True # Important: decodes from bytes to strings
            )
            r.ping()
            print("✅ Redis connection successful!")
            return r
        except redis.exceptions.ConnectionError as e:
            print(f"❌ Redis connection failed: {e}")
            print("Please ensure your Redis Docker container is running.")
            return None

# Test connection when module is run directly
if __name__ == "__main__":
    redis_conn = RedisConnection.get_instance()
    if redis_conn:
        redis_conn.set("test_key", "hello redis")
        value = redis_conn.get("test_key")
        print(f"Got value from Redis: {value}")
        redis_conn.delete("test_key")
        print("Test key deleted.")