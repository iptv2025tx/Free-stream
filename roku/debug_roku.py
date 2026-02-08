import socket
import sys
import time

ROKU_IP = "192.168.5.130"
DEBUG_PORT = 8085
TIMEOUT = 10

print(f"Conectando ao console de debug do Roku em {ROKU_IP}:{DEBUG_PORT}...")
print("(Faca o sideload do ZIP enquanto este script esta rodando)")
print("-" * 60)

try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(TIMEOUT)
    sock.connect((ROKU_IP, DEBUG_PORT))
    print("Conectado! Aguardando output do compilador...")
    print("-" * 60)

    # Read output continuously
    sock.settimeout(2)
    start = time.time()
    while time.time() - start < 120:  # 2 minutes max
        try:
            data = sock.recv(4096)
            if data:
                text = data.decode("utf-8", errors="replace")
                print(text, end="")
                start = time.time()  # Reset timeout on data
            else:
                break
        except socket.timeout:
            continue
        except Exception as e:
            print(f"\nErro: {e}")
            break

except ConnectionRefusedError:
    print(f"Conexao recusada em {ROKU_IP}:{DEBUG_PORT}")
    print("Verifique se o modo developer esta ativo no Roku.")
except socket.timeout:
    print(f"Timeout ao conectar em {ROKU_IP}:{DEBUG_PORT}")
except Exception as e:
    print(f"Erro: {e}")
finally:
    try:
        sock.close()
    except:
        pass
    print("\n" + "-" * 60)
    print("Desconectado.")
