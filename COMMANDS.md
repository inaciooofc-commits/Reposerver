# Comandos do Reposerver

## Monitor de Prompt

- `python3 monitor.py` - abre o monitor padrão com status de reprodução, fila e logs.
- `python3 monitor.py --commands` - exibe a lista de comandos disponíveis no prompt.
- `bash monitor.sh --commands` - mesmo que acima, via script.

## Comandos do Bot RPG (ZarcoBOT)

Para enviar comandos ao bot, use POST em `http://127.0.0.1:6000/command` com JSON:

```json
{
  "who": "seu_nome",
  "text": "roll 1d20+5"
}
```

Comandos suportados:

- `roll <expr>` ou `rolar <expr>`
  - Exemplo: `roll 1d20+5`
  - Exemplo: `rolar 2d6+3`
- `create char <nome>` / `create character <nome>`
  - Cria um personagem com o nome informado.
  - Exemplo: `create char Aramis`
- `show char <nome>` / `show character <nome>`
  - Mostra os dados salvos do personagem.
  - Exemplo: `show char Aramis`
- Qualquer texto servido como mensagem de roleplay
  - O bot ecoa no campo `echo`.

### Rotas úteis do bot

- `GET http://127.0.0.1:6000/help` - retorna os comandos disponíveis do bot.
- `GET http://127.0.0.1:6000/` - retorna uma breve mensagem de boas-vindas.

## Comandos do Servidor Web

- `POST /play` - adiciona música à fila a partir de um link do YouTube.
- `GET /dashboard` - painel do usuário.
- `GET /admin` - painel administrativo (somente admin).
- `POST /admin-action` - cria usuário, ban, créditos e atualiza configuração.
- `POST /buy-credits` - adiciona créditos para o usuário atual.
- `POST /git-update` - atualiza o repositório a partir do Git (admin).
- `POST /bot-command` - envia um comando JSON ao bot RPG local.

## Exemplo de envio de comando ao servidor para o bot

```bash
curl -X POST http://127.0.0.1:5000/bot-command \
  -H 'Content-Type: application/json' \
  -d '{"who":"admin","text":"roll 1d20+5"}'
```
