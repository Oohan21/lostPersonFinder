const express = require('express');
const { createUpdate, getUpdates } = require('../controllers/updateController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router({ mergeParams: true });
console.log('createUpdate:', typeof createUpdate);
console.log('authMiddleware:', typeof authMiddleware);

// Routes
router.post('/', authMiddleware, createUpdate);
router.get('/', getUpdates);

module.exports = router;