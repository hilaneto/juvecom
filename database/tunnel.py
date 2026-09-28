import atexit
import socket
import subprocess
import time
from datetime import datetime

class TunnelError(RuntimeError):
    """Erro relacionado à criação do túnel SSH."""
    pass

class Tunnel:
    """
    Gerencia um túnel SSH utilizando o OpenSSH do sistema.

    Quando use_tunnel=False a classe torna-se transparente,
    permitindo que o restante da aplicação continue utilizando
    a mesma interface sem precisar testar condições.
    Uso:
        tunnel = Tunnel(
            use_tunnel=True,
            host="72.60.10.183",
            ssh_user="hilaneto",
            ssh_key="/home/hilaneto/.ssh/chave"

        tunnel.open()
        ...
        tunnel.close()
    """

    # Inicialização ==========================================================
    def __init__(
        self,
        use_tunnel: bool = True,
        host: str | None = None,
        ssh_user: str | None = None,
        ssh_key: str | None = None,
        local_port: int = 6543,
        remote_host: str = "localhost",
        remote_port: int = 5432,
        ssh_port: int = 22,
        timeout: float = 5.0,):

        self.use_tunnel = use_tunnel
        self.host = host
        self.ssh_user = ssh_user
        self.ssh_key = ssh_key
        self.local_port = int(local_port)
        self.remote_host = remote_host
        self.remote_port = int(remote_port)
        self.ssh_port = int(ssh_port)
        self.timeout = float(timeout)
        self.process = None
        self.opened_at = None
        self.closed_at = None
        atexit.register(self.close)

    # Controle manual ==========================================================
    def open(self):
        if not self.use_tunnel:
            return self

        if self.is_open:
            return self

        return self.__enter__()

    def close(self):
        if not self.use_tunnel:
            return
        if self.process:
            if self.process.poll() is None:
                self.process.terminate()
                self.process.wait()
            self.process = None
            self.closed_at = datetime.now()

    # Estado ==========================================================
    @property
    def is_open(self):
        if not self.use_tunnel:
            return False

        return (self.process is not None
                and self.process.poll() is None)

    @property
    def duration(self):
        if self.opened_at is None:
            return None
        fim = self.closed_at or datetime.now()
        return fim - self.opened_at

    # Validações ==========================================================
    def _porta_livre(self):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            return sock.connect_ex( ("127.0.0.1", self.local_port) ) != 0

    def _traduz_erro(self, erro):
        erro = erro.strip()
        if "Permission denied" in erro:
            return ( "Falha na autenticação SSH.\n"
                     "Verifique usuário e chave privada." )

        if "Connection timed out" in erro:
            return "Tempo esgotado ao conectar ao servidor SSH."

        if "Connection refused" in erro:
            return "O servidor recusou a conexão SSH."

        if "Host key verification failed" in erro:
            return "Falha na verificação da chave do servidor SSH."

        if "Could not resolve hostname" in erro:
            return f'Host "{self.host}" não encontrado.'

        return f"Erro do OpenSSH:\n{erro}"

    # Context Manager ==========================================================
    def __enter__(self):
        if not self.use_tunnel:
            return self

        if self.is_open:
            return self

        if not self._porta_livre():
            raise TunnelError( f"A porta local {self.local_port} já está em uso." )

        comando = [ "ssh",
                    "-N",
                    "-i",
                    self.ssh_key,
                    "-p",
                    str(self.ssh_port),
                    "-L",
                    f"{self.local_port}:{self.remote_host}:{self.remote_port}",
                    f"{self.ssh_user}@{self.host}"]

        try:
            self.process = subprocess.Popen(
                comando,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True, )

        except FileNotFoundError:
            raise TunnelError(
                "O comando ssh não foi encontrado." )

        inicio = time.time()

        while True:
            if not self._porta_livre():
                self.opened_at = datetime.now()
                return self

            if self.process.poll() is not None:
                erro = self.process.stderr.read()
                self.process.wait()
                self.process = None
                raise TunnelError(
                    self._traduz_erro(erro) )

            if time.time() - inicio > self.timeout:
                self.close()
                raise TunnelError( "Tempo esgotado aguardando o túnel SSH." )

            time.sleep(0.1)

    def __exit__(self, exc_type, exc_value, traceback):

        self.close()