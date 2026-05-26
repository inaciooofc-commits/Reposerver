
const fs = require('fs');
const path = require('path');

const usersFilePath = path.join(__dirname, '../users.json');

const getUsers = (req, res) => {
  fs.readFile(usersFilePath, 'utf8', (err, data) => {
    if (err) {
      console.error(err);
      return res.status(500).send('Erro ao ler o arquivo de usuários.');
    }
    res.json(JSON.parse(data));
  });
};

module.exports = {
  getUsers,
};
