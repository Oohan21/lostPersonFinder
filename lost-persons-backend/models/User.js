const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
    email: {
        type: String,
        required: true,
        unique: true,
        trim: true,
        lowercase: true // Automatically convert to lowercase
    },
    password: { type: String, required: true },
    name: { type: String, required: true, trim: true },
    contactInfo: { type: String, trim: true },
    role: { type: String, enum: ['user', 'admin', 'verified_contact'], default: 'user' },
    phone: { type: String },
    profilePicture: { type: String },
    createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('User', userSchema);