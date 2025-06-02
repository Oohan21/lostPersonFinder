const express = require('express');
const router = express.Router();
const { register, login, validateToken } = require('../controllers/authController');
const auth = require('../middleware/authMiddleware');

// Register
router.post('/register', register);

// Login
router.post('/login', login);

// Logout
router.post('/logout', auth, (req, res) => {
    try {
        // In a real app, you might invalidate the token here (e.g., by adding it to a blacklist)
        res.status(200).json({ message: 'Logout successful' });
    } catch (err) {
        console.error('Logout error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
});
router.get('/validate', auth, validateToken);
router.post('/refresh', auth, (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const newToken = jwt.sign({ id: decoded.id, role: decoded.role }, process.env.JWT_SECRET, { expiresIn: '7d' });
        res.json({ token: newToken });
    } catch (err) {
        console.error('Refresh error:', err);
        res.status(401).json({ message: 'Invalid token', error: err.message });
    }
});

module.exports = router;