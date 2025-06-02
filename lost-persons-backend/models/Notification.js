const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    message: { type: String, required: true },
    type: { type: String, enum: ['sighting', 'message', 'report'], required: true },
    reportId: { type: mongoose.Schema.Types.ObjectId, ref: 'MissingPerson' },
    conversationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Conversation' },
    otherParticipantName: String,
    read: { type: Boolean, default: false },
    createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Notification', notificationSchema);