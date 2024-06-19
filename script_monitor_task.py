import requests
import time
import json

# Configurações do Proxmox
proxmox_host = "https://192.168.100.37:8006"
user = "root@pam"
password = "Eunaoseiasenha22!"
task_id = "TASK_ID"  # Substitua pelo ID da tarefa real

# Função para obter o ticket de autenticação
def get_auth_ticket(proxmox_host, user, password):
    url = f"{proxmox_host}/api2/json/access/ticket"
    payload = {"username": user, "password": password}
    response = requests.post(url, data=payload, verify=False)
    data = response.json()["data"]
    return data["ticket"], data["CSRFPreventionToken"]

# Função para monitorar a tarefa
def monitor_task(proxmox_host, task_id, ticket, csrf_token):
    url = f"{proxmox_host}/api2/json/nodes/pve/tasks/{task_id}/status"
    headers = {
        "Cookie": f"PVEAuthCookie={ticket}",
        "CSRFPreventionToken": csrf_token
    }

    while True:
        response = requests.get(url, headers=headers, verify=False)
        task_status = response.json()["data"]

        if task_status["status"] == "stopped":
            if task_status["exitstatus"] == "OK":
                print("Clonagem concluída com sucesso!")
            else:
                print("Erro na clonagem:", task_status["exitstatus"])
            break

        print(f"Progresso: {task_status['status']}")
        time.sleep(5)  # Ajuste o tempo conforme necessário

if __name__ == "__main__":
    ticket, csrf_token = get_auth_ticket(proxmox_host, user, password)
    monitor_task(proxmox_host, task_id, ticket, csrf_token)
