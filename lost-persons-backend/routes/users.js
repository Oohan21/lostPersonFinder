const express = require('express');
const User = require('../models/User');
const auth = require('../middleware/authMiddleware');

const router = express.Router();

// Get All Users (Admin)
router.get('/', auth, async (req, res) => {
    try {
        if (req.user.role !== 'admin') {
            return res.status(403).json({ message: 'Unauthorized' });
        }
        const users = await User.find().select('name email phone role');
        res.json(users);
    } catch (err) {
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;