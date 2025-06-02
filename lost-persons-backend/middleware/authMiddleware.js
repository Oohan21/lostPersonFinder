const jwt = require('jsonwebtoken');
const User = require('../models/User');

const authMiddleware = async (req, res, next) => {
    const authHeader = req.header('Authorization');
    if (!authHeader) {
        console.error('Auth middleware: No Authorization header provided');
        return res.status(401).json({ message: 'No token provided' });
    }

    const token = authHeader.replace('Bearer ', '');
    if (!token) {
        console.error('Auth middleware: Malformed Authorization header');
        return res.status(401).json({ message: 'Invalid token format' });
    }

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        if (!decoded.id) {
            console.error('Auth middleware: Token missing id', decoded);
            return res.status(401).json({ message: 'Invalid token: No user ID found' });
        }

        const user = await User.findById(decoded.id).select('id role');
        if (!user) {
            console.error('Auth middleware: User not found for id', decoded.id);
            return res.status(401).json({ message: 'Unauthorized: No user found' });
        }

        req.user = { id: user.id.toString(), role: user.role || 'user' };
        console.log(`Auth middleware: User authenticated, id: ${req.user.id}, role: ${req.user.role}`);
        next();
    } catch (error) {
        console.error('Auth middleware error:', error.message, error.stack);
        res.status(401).json({ message: 'Unauthorized: Invalid or expired token' });
    }
};
module.exports = authMiddleware;