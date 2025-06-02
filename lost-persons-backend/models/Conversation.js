const mongoose = require('mongoose');

const conversationSchema = new mongoose.Schema({
    reportId: { type: String, required: true },
    participants: [{ id: { type: mongoose.Schema.Types.ObjectId, ref: 'User' } }],

    lastMessage: {
        content: String,
        sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        createdAt: Date,
    },
    createdAt: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now },
});
conversationSchema.pre('save', function (next) {
    this.updatedAt = new Date();
    next();
});
module.exports = mongoose.model('Conversation', conversationSchema);