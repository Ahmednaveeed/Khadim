# database_connection.py
import os
from urllib.parse import urlparse
import psycopg2
from infrastructure.config import DATABASE_URL


class DatabaseConnection:
    """Singleton database connection class for Khadim restaurant system"""

    _instance = None

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = DatabaseConnection()
        return cls._instance

    def __init__(self):
        db_url = DATABASE_URL or os.getenv("DATABASE_URL")
        if not db_url:
            raise RuntimeError("DATABASE_URL is not set")

        parsed = urlparse(db_url)

        self.conn_params = {
            "dbname": parsed.path.lstrip("/"),
            "user": parsed.username,
            "password": parsed.password,
            "host": parsed.hostname,
            "port": parsed.port or 5432,
            "connect_timeout": 5,  # prevents hanging connects
            "options": "-c statement_timeout=20000",  # 20s query max
        }

    def get_connection(self):
        try:
            return psycopg2.connect(**self.conn_params)
        except psycopg2.Error as e:
            print(f"Database connection error: {e}")
            raise

    def test_connection(self) -> bool:
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT 1")
                    return True
        except:
            return False