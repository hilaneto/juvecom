from peewee import PostgresqlDatabase, OperationalError
from dotenv import load_dotenv
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

# Context Manager ==================================================
class Conexao:
    def __enter__(self):
        try:
            tunnel.open()
            db.connect(reuse_if_open=True)
            return db
        except OperationalError as erro:
            tunnel.close()
            raise RuntimeError(
                f"Erro ao conectar ao PostgreSQL:\n{erro}") from erro

    def __exit__(self, exc_type, exc_value, traceback):
        if not db.is_closed():
            db.close()
        tunnel.close()

# Interface pública ==================================================
def conectar():
    return Conexao()

