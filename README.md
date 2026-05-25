# Reposerver anime para antiX

Servidor local com painel web, integração com YouTube, música, controle de usuários, sistema de ban, créditos e monitor de terminal.

## Arquivos principais

- `install.sh` - instala dependências e cria o servidor em `/opt/reposerver`
- `start.sh` - inicia o servidor web
- `monitor.sh` - abre o monitor de prompt com status em tempo real
- `server.py` - servidor Flask com painel
- `monitor.py` - monitor CLI com interface de terminal
- `config.json` - configurações de tema, música, Google OAuth e atualização automática pelo Git
- `requirements.txt` - dependências Python

## Instalação no antiX

1. Copie este diretório para o seu sistema antiX.
2. Abra terminal e faça:

```bash
sudo bash install.sh
```

3. Inicie o servidor:

```bash
sudo bash /opt/reposerver/start.sh
```

4. Abra o navegador em:

```text
http://<IP_DO_PC>:5000
```

5. Login padrão:

- Usuário: `admin`
- Senha: `admin123`

6. Para abrir o monitor no prompt:

```bash
sudo bash /opt/reposerver/monitor.sh
```

## Configuração

- `config.json` permite trocar a música de fundo e os temas.
- `users.json` armazena usuários, senhas e créditos.
- `ip_log.json` armazena IPs de login.
- `payments.json` armazena transações.

## Recursos incluídos

- painel web com tema anime e animações
- controle de usuários e banimento
- sistema de créditos e pagamento simulado
- integração com YouTube para tocar músicas
- login com Google via OAuth (quando configurado)
- atualização do servidor a partir do Git pelo painel administrativo
- atualização automática pelo Git ao iniciar (opcional)
- monitor de prompt com logs em tempo real
- armazenamento local de IPs e atividades
