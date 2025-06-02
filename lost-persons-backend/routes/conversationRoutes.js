const express = require('express');
const router = express.Router();
const { createConversation, getConversations, getConversation, getOrCreateConversation } = require('../controllers/conversationController');
const auth = require('../middleware/authMiddleware');

router.post('/', auth, createConversation);
router.get('/:conversationId', auth, getConversation);
router.get('/:conversationId', auth, getOrCreateConversation);
router.get('/', auth, getConversations);

module.exports = router;