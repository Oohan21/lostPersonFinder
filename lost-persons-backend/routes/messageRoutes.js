const express = require('express');
const router = express.Router();
const auth = require('../middleware/authMiddleware');
const { sendMessage, getMessages } = require('../controllers/messageController');

// Send a new message
router.post('/', auth, sendMessage);

// Get messages for a specific conversation
router.get('/:conversationId', auth, getMessages);

module.exports = router;