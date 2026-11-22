from apscheduler.schedulers.blocking import BlockingScheduler
from models.contrato_status import ContratoStatus

def atualizar_contratos():
    ContratoStatus.atualizar_inadimplencia()

if __name__ == "__main__":
    scheduler = BlockingScheduler(timezone="America/Sao_Paulo")
    scheduler.add_job(atualizar_contratos, "cron", hour=0, minute=10)
    scheduler.start()
    