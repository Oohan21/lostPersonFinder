const User = require('../models/User');

const register = async (req, res) => {
    const { name, email, password, role } = req.body;

    try {
        const missingFields = [];
        if (!name) missingFields.push('name');
        if (!email) missingFields.push('email');
        if (!password) missingFields.push('password');
        if (missingFields.length > 0) {
            return res.status(400).json({ message: `Missing required fields: ${missingFields.join(', ')}` });
        }

        const normalizedEmail = email.trim().toLowerCase();
        console.log(`Register - Received body: ${JSON.stringify(req.body)}`);
        console.log(`Register - Checking for email: ${normalizedEmail}`);
        const existingUser = await User.findOne({ email: normalizedEmail });
        if (existingUser) {
            console.log(`Register - Email already exists: ${normalizedEmail}`);
            return res.status(400).json({ message: 'Email already exists' });
        }

        const user = new User({
            name,
            email: normalizedEmail,
            password: password, // Store plain text password
            role: role || 'user',
        });

        await user.save();
        console.log(`Register - User created: ${user.id}`);

        const token = require('jsonwebtoken').sign(
            { id: user.id, role: user.role },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );
        console.log('Register - Generated token:', token);

        res.status(201).json({
            message: 'User registered successfully',
            token,
            user: { id: user.id, name, email: normalizedEmail, role: user.role },
        });
    } catch (err) {
        console.error('Register error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

const login = async (req, res) => {
    try {
        const { email, password } = req.body;
        const missingFields = [];
        if (!email) missingFields.push('email');
        if (!password) missingFields.push('password');
        if (missingFields.length > 0) {
            console.log(`Login - Missing fields: ${missingFields.join(', ')}`);
            return res.status(400).json({ message: `Missing required fields: ${missingFields.join(', ')}` });
        }

        const normalizedEmail = email.trim().toLowerCase();
        console.log(`Login - Received body: ${JSON.stringify(req.body)}`);
        console.log(`Login - Searching for email: ${normalizedEmail}`);
        const user = await User.findOne({ email: normalizedEmail });
        if (!user) {
            console.log(`Login - Email not found: ${normalizedEmail}`);
            return res.status(400).json({ message: 'Email not found' });
        }

        console.log(`Login - Found user: ${user.id}, comparing password`);
        if (user.password !== password) { // Compare plain text
            console.log(`Login - Password mismatch for email: ${normalizedEmail}`);
            return res.status(400).json({ message: 'Incorrect password' });
        }

        const token = require('jsonwebtoken').sign(
            { id: user.id, role: user.role },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );
        console.log('Login - Generated token:', token);

        res.json({
            message: 'Login successful',
            token,
            user: { id: user.id, name: user.name, email: user.email, role: user.role },
        });
    } catch (err) {
        console.error('Login error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};
const validateToken = async (req, res) => {
    try {
        if (!req.user) {
            console.log('Validate - No user in request');
            return res.status(401).json({ message: 'Invalid token: No user data' });
        }
        const user = await User.findById(req.user.id).select('name email role');
        if (!user) {
            console.log('Validate - User not found for ID:', req.user.id);
            return res.status(401).json({ message: 'Invalid token: User not found' });
        }

        console.log('Validate - User found:', { id: user._id, name: user.name, email: user.email, role: user.role });
        res.status(200).json({ valid: true, user: { id: user._id, name: user.name, email: user.email, role: user.role } });
    } catch (err) {
        console.error('Token validation error:', err);
        res.status(401).json({ message: 'Invalid token', error: err.message });
    }
};
module.exports = { register, login, validateToken };