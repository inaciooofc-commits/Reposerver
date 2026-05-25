const { default: makeWASocket, useSingleFileAuthState, DisconnectReason } = require('@adiwajshing/baileys')
const qrcode = require('qrcode-terminal')
const P = require('pino')
const fs = require('fs')

const AUTH_FILE = './auth_info_multi.json'
const { state, saveState } = useSingleFileAuthState(AUTH_FILE)

async function start() {
  const sock = makeWASocket({ auth: state, printQRInTerminal: false, logger: P({ level: 'info' }) })

  sock.ev.on('creds.update', saveState)

  sock.ev.on('connection.update', (update) => {
    const { connection, lastDisconnect, qr } = update
    if (qr) {
      qrcode.generate(qr, { small: true })
      console.log('QR gerado — escaneie com o WhatsApp (QRCode acima)')
    }
    if (connection === 'close') {
      const shouldReconnect = (lastDisconnect.error && lastDisconnect.error.output && lastDisconnect.error.output.statusCode !== 401)
      console.log('connection closed, reconnecting', lastDisconnect.error)
      if (shouldReconnect) start()
    }
    if (connection === 'open') {
      console.log('Conectado ao WhatsApp!')
    }
  })

  sock.ev.on('messages.upsert', async (m) => {
    try {
      const message = m.messages[0]
      if (!message.message) return
      const from = message.key.remoteJid
      const text = message.message.conversation || (message.message.extendedTextMessage && message.message.extendedTextMessage.text)
      console.log('msg from', from, text)
      // aqui você pode encaminhar para o server via HTTP, gravar logs, etc.
    } catch (e) {
      console.error(e)
    }
  })
}

start().catch(e => console.error('Falha ao iniciar Baileys', e))
