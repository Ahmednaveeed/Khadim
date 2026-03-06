"""Redis connection utilities."""

import os
import redis


class RedisConnection:
    """Singleton Redis connection class."""

    _instance = None

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls._create_instance()
        return cls._instance

    @staticmethod
    def _create_instance():
        host = os.getenv("REDIS_HOST", "127.0.0.1")
        port = int(os.getenv("REDIS_PORT", 6379))

        r = redis.Redis(
            host=host,
            port=port,
            db=0,
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=2,
            retry_on_timeout=True,
        )

        # Fail fast if Redis isn't reachable
        r.ping()
        return r