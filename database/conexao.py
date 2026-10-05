from peewee import PostgresqlDatabase, OperationalError
from dotenv import load_dotenv
from threading import RLock
from database.tunnel import Tunnel
import os

# Carrega variáveis de ambiente ==================================================
load_dotenv()

# Configuração do túnel ==================================================
use_tunnel = os.getenv("USE_SSH_TUNNEL", "False") == "True"

tunnel = Tunnel(
    use_tunnel=use_tunnel,
    host=os.getenv("SSH_HOST"),
    ssh_user=os.getenv("SSH_USER"),
    ssh_key=os.getenv("SSH_KEY"),
    local_port=os.getenv("SSH_LOCAL_PORT", 6543),
    remote_host=os.getenv("SSH_REMOTE_HOST", "localhost"),
    remote_port=os.getenv("SSH_REMOTE_PORT", 5432),
    ssh_port=os.getenv("SSH_PORT", 22),
    timeout=os.getenv("SSH_TIMEOUT", 5))

# Banco PostgreSQL ==================================================
db = PostgresqlDatabase(
    database=os.getenv("PG_DATABASE"),
    user=os.getenv("PG_USER"),
    password=os.getenv("PG_PASSWORD"),
    host=os.getenv("PG_HOST"),
    port=int(os.getenv("PG_PORT")))


controle_tunel = RLock()

# Context Manager ==========================
class Conexao:
    def __enter__(self):
        self.travou = False
        self.abriu_tunel = False
        self.abriu_banco = False

        if use_tunnel:
            controle_tunel.acquire()
            self.travou = True

        try:
            if use_tunnel and not tunnel.is_open:
                tunnel.open()
                self.abriu_tunel = True

            if db.is_closed():
                db.connect()
                self.abriu_banco = True

            return db

        except Exception:
            self.__exit__(None, None, None)
            raise

    def __exit__(self, exc_type, exc_value, traceback):
        try:
            if self.abriu_banco and not db.is_closed():
                db.close()
        finally:
            try:
                if self.abriu_tunel:
                    tunnel.close()
            finally:
                if self.travou:
                    controle_tunel.release()


# Interface pública ==================================================
def conectar():
    return Conexao()

