const mongoose = require('mongoose');

const updateSchema = new mongoose.Schema({
    missingPerson: { type: mongoose.Schema.Types.ObjectId, ref: 'MissingPerson', required: true },
    author: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    content: { type: String, required: true },
    isOfficial: { type: Boolean, default: false },
    createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Update', updateSchema);