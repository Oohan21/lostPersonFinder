const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');

const missingPersonSchema = new mongoose.Schema({
    reportId: { type: String, unique: true, required: true },
    name: { type: String, required: true },
    age: { type: Number, required: true },
    phone: { type: String, required: true },
    gender: { type: String, enum: ['Male', 'Female'], required: true },
    lastSeen: {
        dateTime: { type: Date, default: Date.now },
        address: { type: String, default: 'Unknown' },
        coordinates: {
            type: { type: String, enum: ['Point'], default: 'Point' },
            coordinates: { type: [Number], default: [0, 0] },
        },
    },
    description: { type: String },
    photos: [{ type: String }],
    videos: [{ type: String }],
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    weight: { type: String },
    height: { type: String },
    hairColor: { type: String },
    eyeColor: { type: String },
    markup: { type: String },
    skinColor: { type: String },
    policeReportNumber: { type: String },
    bonus: { type: String },
    createdAt: { type: Date, default: Date.now },
    status: { type: String, enum: ['active', 'resolved'], default: 'active' },
});

missingPersonSchema.index({ 'lastSeen.coordinates': '2dsphere' });

module.exports = mongoose.model('MissingPerson', missingPersonSchema);