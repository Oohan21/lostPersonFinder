const mongoose = require('mongoose');

const sightingSchema = new mongoose.Schema({
    reportId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'MissingPerson',
        required: true,
    },
    description: {
        type: String,
        required: true,
        trim: true,
    },
    location: {
        dateTime: {
            type: Date,
            required: true,
        },
        address: {
            type: String,
            trim: true,
        },
    },
    photos: [{
        type: String,
    }],
    createdBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
    },
    createdAt: { type: Date, default: Date.now },
    contactInfo: {
        name: {
            type: String,
            trim: true,
        },
        phone: {
            type: String,
            trim: true,
        },
        email: {
            type: String,
            trim: true,
        },
    },
    status: {
        type: String,
        enum: ['pending', 'verified', 'rejected'],
        default: 'pending',
    },
}, {
    timestamps: true,
});

module.exports = mongoose.model('Sighting', sightingSchema);
