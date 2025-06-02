const User = require('../models/User');

const getProfile = async (req, res) => {
    try {
        const user = await User.findById(req.user.id).select('-password');
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        res.json(user);
    } catch (err) {
        console.error('Get profile error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

const updateProfile = async (req, res) => {
    const { name, email, phone } = req.body;
    const file = req.file;
    try {
        console.log('Request headers:', req.headers);
        console.log('Incoming body:', req.body);
        console.log('Incoming file:', req.file);
        const user = await User.findById(req.user.id);
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        if (name) user.name = name;
        if (email) user.email = email;
        if (phone) user.phone = phone;

        if (file) {
            console.log('Received file:', file);
            console.log('Saved profile picture path:', file.path);
            user.profilePicture = file.path;
        }

        await user.save();
        res.status(200).json({ message: 'Profile updated', user: { name: user.name, email: user.email, phone: user.phone, profilePicture: user.profilePicture } });
    } catch (err) {
        console.error('Update profile error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};
// controllers/userController.js
const getUsers = async (req, res) => {
    try {
        if (!req.user || !req.user.id) {
            return res.status(401).json({ message: 'Unauthorized: No user found' });
        }
        if (req.user.role !== 'admin') {
            return res.status(403).json({ message: 'Unauthorized: Admin access required' });
        }
        const users = await User.find().select('name email phone role');
        res.status(200).json(
            users.map(user => ({
                id: user.id.toString(),
                name: user.name || 'Unknown',
                email: user.email || '',
                phone: user.phone || null,
                role: user.role || 'user',
            }))
        );
    } catch (error) {
        console.error('Get users error:', error.message, error.stack);
        res.status(500).json({ message: 'Server error', error: error.message });
    }
};

module.exports = { getProfile, updateProfile, getUsers };