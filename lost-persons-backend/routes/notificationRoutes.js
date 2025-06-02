const express = require('express');
const router = express.Router();
const auth = require('../middleware/authMiddleware');
const { getNotifications, markNotificationAsRead } = require('../controllers/notificationController');

// Get all notifications for the authenticated user
router.get('/', auth, getNotifications);

// Mark a notification as read
router.patch('/:notificationId/read', auth, markNotificationAsRead);

module.exports = router;