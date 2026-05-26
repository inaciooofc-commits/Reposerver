
const express = require('express');
const path = require('path');
const nunjucks = require('nunjucks');
const fs = require('fs');
const session = require('express-session');
const app = express();
const port = 3000;

// Helper para ler/escrever JSON
function readJsonFile(filePath, callback) {
    fs.readFile(filePath, 'utf8', (err, data) => {
        if (err) {
            if (err.code === 'ENOENT') {
                const emptyData = ['queue.json', 'missions.json', 'shop.json', 'staff_applications.json'].some(name => filePath.includes(name)) ? [] : {};
                return callback(null, emptyData);
            }
            return callback(err);
        }
        if (!data.trim()) {
            const emptyData = ['queue.json', 'missions.json', 'shop.json', 'staff_applications.json'].some(name => filePath.includes(name)) ? [] : {};
            return callback(null, emptyData);
        }
        try {
            callback(null, JSON.parse(data));
        } catch (parseErr) {
            callback(parseErr);
        }
    });
}

function writeJsonFile(filePath, jsonData, callback) {
    fs.writeFile(filePath, JSON.stringify(jsonData, null, 2), 'utf8', callback);
}

// Config
const njk = nunjucks.configure('public', { autoescape: true, express: app });
njk.addFilter('date', (timestamp, format) => {
    const date = new Date(timestamp);
    if (format === 'dd/MM/yyyy HH:mm') {
        return date.toLocaleString('pt-BR', { timeZone: 'UTC' });
    }
    return date.toISOString();
});

app.use(express.static('public'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(session({
    secret: 'uma-chave-secreta-super-forte',
    resave: false,
    saveUninitialized: true,
    cookie: { secure: false }
}));

function isAuthenticated(req, res, next) {
    if (req.session.user) return next();
    res.redirect('/');
}

// Auth Routes
app.get('/', (req, res) => {
    if (req.session.user) return res.redirect('/dashboard');
    res.render('login.html', { messages: req.session.messages || [] });
    req.session.messages = [];
});

app.post('/login', (req, res) => {
    const { username, password } = req.body;
    readJsonFile(path.join(__dirname, 'data', 'users.json'), (err, users) => {
        if (err) {
            req.session.messages = [{ category: 'error', text: 'Erro interno do servidor.' }];
            return res.redirect('/');
        }
        const user = users[username];
        if (user && user.password === password) {
            if (user.banned) {
                req.session.messages = [{ category: 'error', text: 'Este usuário está banido.' }];
                return res.redirect('/');
            }
            req.session.user = { username: username, role: user.role };
            res.redirect('/dashboard');
        } else {
            req.session.messages = [{ category: 'error', text: 'Usuário ou senha inválidos.' }];
            res.redirect('/');
        }
    });
});

app.get('/logout', (req, res) => {
    req.session.destroy(() => res.redirect('/'));
});

// Dashboard Routes
app.get('/dashboard', isAuthenticated, (req, res) => {
    const dataFiles = {
        users: path.join(__dirname, 'data', 'users.json'),
        queue: path.join(__dirname, 'data', 'queue.json'),
        status: path.join(__dirname, 'data', 'status.json'),
        config: path.join(__dirname, 'data', 'config.json')
    };
    const results = {};
    let filesRead = 0;
    const totalFiles = Object.keys(dataFiles).length;

    Object.keys(dataFiles).forEach(key => {
        readJsonFile(dataFiles[key], (err, data) => {
            if (err) return res.status(500).send(`Erro ao carregar ${key}.`);
            results[key] = data;
            if (++filesRead === totalFiles) {
                const latestUserData = results.users[req.session.user.username];
                if (!latestUserData) {
                    req.session.destroy();
                    return res.redirect('/');
                }
                const user = { ...req.session.user, ...latestUserData };

                res.render('dashboard.html', {
                    panel_title: 'Painel Ninja',
                    background_image: 'https://i.imgur.com/7Bv0C5B.jpg',
                    user: user,
                    current: results.status.current || null,
                    queue: results.queue || [],
                    background_music: results.config.background_music || null,
                    messages: req.session.messages || []
                });
                req.session.messages = [];
            }
        });
    });
});

app.post('/api/play', isAuthenticated, (req, res) => {
    const { youtube_url } = req.body;
    if (!youtube_url) {
        req.session.messages = [{ category: 'error', text: 'URL do YouTube é necessária.' }];
        return res.redirect('/dashboard');
    }
    const queueFilePath = path.join(__dirname, 'data', 'queue.json');
    readJsonFile(queueFilePath, (err, queue) => {
        if (err) {
            req.session.messages = [{ category: 'error', text: 'Erro ao ler a fila.' }];
            return res.redirect('/dashboard');
        }
        queue.push({ url: youtube_url, requestor: req.session.user.username, timestamp: Date.now() });
        writeJsonFile(queueFilePath, queue, (writeErr) => {
            req.session.messages = writeErr ? 
                [{ category: 'error', text: 'Erro ao salvar a fila.' }] : 
                [{ category: 'success', text: 'Sua música foi adicionada à fila de missões!' }];
            res.redirect('/dashboard');
        });
    });
});

app.post('/dashboard/apply-for-staff', isAuthenticated, (req, res) => {
    const applicationsFilePath = path.join(__dirname, 'data', 'staff_applications.json');
    readJsonFile(applicationsFilePath, (err, applications) => {
        if (err) {
            req.session.messages = [{ category: 'error', text: 'Erro ao ler o arquivo de aplicações.' }];
            return res.redirect('/dashboard');
        }

        // Checar se o usuário já aplicou
        if (applications.find(app => app.username === req.session.user.username)) {
            req.session.messages = [{ category: 'warning', text: 'Você já enviou uma aplicação.' }];
            return res.redirect('/dashboard');
        }

        const newApplication = { username: req.session.user.username, timestamp: Date.now() };
        applications.push(newApplication);

        writeJsonFile(applicationsFilePath, applications, (writeErr) => {
            req.session.messages = writeErr ?
                [{ category: 'error', text: 'Erro ao salvar sua aplicação.' }] :
                [{ category: 'success', text: 'Sua aplicação para Jounin foi enviada para análise!' }];
            res.redirect('/dashboard');
        });
    });
});

// Missions and Shop Routes
app.get('/missions', isAuthenticated, (req, res) => {
    readJsonFile(path.join(__dirname, 'data', 'missions.json'), (err, missions) => {
        if (err) return res.status(500).send('Erro ao carregar as missões.');
        res.render('missions.html', { missions: missions });
    });
});

app.get('/shop', isAuthenticated, (req, res) => {
    readJsonFile(path.join(__dirname, 'data', 'shop.json'), (err, items) => {
        if (err) return res.status(500).send('Erro ao carregar a loja.');
        readJsonFile(path.join(__dirname, 'data', 'users.json'), (userErr, users) => {
            if (userErr) return res.status(500).send('Erro ao carregar dados do usuário.');
            const user = users[req.session.user.username];
            res.render('shop.html', { items: items, user: user });
        });
    });
});

// Admin Routes
app.get('/admin', isAuthenticated, (req, res) => {
    if (req.session.user.role !== 'admin') return res.status(403).send('Acesso negado.');
    const dataFiles = { users: path.join(__dirname, 'data/users.json'), queue: path.join(__dirname, 'data/queue.json'), status: path.join(__dirname, 'data/status.json'), config: path.join(__dirname, 'data/config.json'), applications: path.join(__dirname, 'data/staff_applications.json') };
    const results = {};
    let filesRead = 0;
    const totalFiles = Object.keys(dataFiles).length;
    for (const key in dataFiles) {
        readJsonFile(dataFiles[key], (err, data) => {
            results[key] = data || (['queue', 'applications'].includes(key) ? [] : {});
            if (++filesRead === totalFiles) {
                res.render('admin.html', { title: 'Painel Admin', users: results.users, queue: results.queue, status: results.status, config: results.config, applications: results.applications, error: null, messages: req.session.messages || [] });
                req.session.messages = [];
            }
        });
    }
});

app.post('/admin/action', isAuthenticated, (req, res) => {
    if (req.session.user.role !== 'admin') return res.status(403).send('Acesso negado.');
    const { action, username, password, credits } = req.body;

    const usersFilePath = path.join(__dirname, 'data', 'users.json');
    const applicationsFilePath = path.join(__dirname, 'data', 'staff_applications.json');

    const handleResponse = (err, msg) => {
        req.session.messages = err ? [{ category: 'error', text: err }] : [{ category: 'success', text: msg }];
        res.redirect('/admin');
    };

    switch (action) {
        case 'create_user':
            readJsonFile(usersFilePath, (err, users) => {
                if (err) return handleResponse('Erro ao ler dados de usuários.');
                if (username && password && !users[username]) {
                    users[username] = { password, role: 'user', xp: 0, level: 1, credits: 0, gold: 0, banned: false, items: [], warnings: 0 };
                    writeJsonFile(usersFilePath, users, (writeErr) => handleResponse(writeErr, `Ninja ${username} registrado.`));
                } else {
                    handleResponse('Nome de usuário inválido ou já existente.');
                }
            });
            break;
        case 'toggle_ban':
            readJsonFile(usersFilePath, (err, users) => {
                if (err) return handleResponse('Erro ao ler dados de usuários.');
                if (username && users[username]) {
                    users[username].banned = !users[username].banned;
                    writeJsonFile(usersFilePath, users, (writeErr) => handleResponse(writeErr, `Status de ${username} alterado.`));
                } else {
                    handleResponse('Usuário não encontrado.');
                }
            });
            break;
        case 'grant_credits':
            readJsonFile(usersFilePath, (err, users) => {
                if (err) return handleResponse('Erro ao ler dados de usuários.');
                if (username && users[username] && credits) {
                    users[username].gold = (users[username].gold || 0) + parseInt(credits, 10);
                    writeJsonFile(usersFilePath, users, (writeErr) => handleResponse(writeErr, `${credits} de gold concedidos a ${username}.`));
                } else {
                    handleResponse('Usuário ou valor inválido.');
                }
            });
            break;
        case 'promote_to_jounin':
            readJsonFile(usersFilePath, (err, users) => {
                if (err) return handleResponse('Erro ao ler dados de usuários.');
                if (users[username]) {
                    users[username].role = 'jounin';
                    writeJsonFile(usersFilePath, users, (writeErr) => {
                        if (writeErr) return handleResponse(writeErr);
                        readJsonFile(applicationsFilePath, (appErr, applications) => {
                            if (appErr) return handleResponse('Erro ao ler aplicações.');
                            const updatedApplications = applications.filter(app => app.username !== username);
                            writeJsonFile(applicationsFilePath, updatedApplications, (appWriteErr) => {
                                handleResponse(appWriteErr, `${username} foi promovido a Jounin.`);
                            });
                        });
                    });
                } else {
                    handleResponse('Usuário não encontrado.');
                }
            });
            break;
        case 'deny_application':
            readJsonFile(applicationsFilePath, (err, applications) => {
                if (err) return handleResponse('Erro ao ler aplicações.');
                const updatedApplications = applications.filter(app => app.username !== username);
                writeJsonFile(applicationsFilePath, updatedApplications, (writeErr) => {
                    handleResponse(writeErr, `Aplicação de ${username} recusada.`);
                });
            });
            break;
        default:
            handleResponse('Ação desconhecida.');
    }
});

// Bot command webhook
app.post('/api/bot-command', (req, res) => {
    const { command } = req.body;
    console.log(`Comando recebido do bot: ${command}`);
    res.json({ status: 'Comando recebido com sucesso!', command });
});

app.listen(port, () => {
    console.log(`Servidor robusto rodando em http://localhost:${port}`);
});
