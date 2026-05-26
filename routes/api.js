
const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');

// Rota para obter usuários
router.get('/users', userController.getUsers);

module.exports = router;
