const Update = require('../models/Update');
const MissingPerson = require('../models/MissingPerson');

// Post an official update
const createUpdate = async (req, res) => {
    const { content, isOfficial } = req.body;
    const { id: missingPersonId } = req.params;

    try {
        if (!content) {
            return res.status(400).json({ message: 'Content is required' });
        }
        // Verify missing person exists
        const missingPerson = await MissingPerson.findById(missingPersonId);
        if (!missingPerson) {
            return res.status(404).json({ message: 'Missing person not found' });
        }

        // Only admins or verified contacts can post official updates
        if (isOfficial && req.user.role !== 'admin' && req.user.role !== 'verified_contact') {
            return res.status(403).json({ message: 'Only admins or verified contacts can post official updates' });
        }

        // Restrict update posting to admins, verified contacts, or the reporter
        if (
            req.user.role !== 'admin' &&
            req.user.role !== 'verified_contact' &&
            missingPerson.reporter.toString() !== req.user.id
        ) {
            return res.status(403).json({ message: 'Unauthorized to post updates for this report' });
        }

        const update = new Update({
            missingPerson: missingPersonId,
            author: req.user.id,
            content,
            isOfficial: isOfficial || false,
        });

        await update.save();
        res.status(201).json({ message: 'Update posted', update });
    } catch (err) {
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Get updates for a missing person
const getUpdates = async (req, res) => {
    const { id: missingPersonId } = req.params;

    try {
        // Verify missing person exists
        const missingPerson = await MissingPerson.findById(missingPersonId);
        if (!missingPerson) {
            return res.status(404).json({ message: 'Missing person not found' });
        }

        // Privacy control: Non-authenticated users only see updates for public reports
        if (!req.user && !missingPerson.privacySettings.sharePublicly) {
            return res.status(403).json({ message: 'Access denied: Report is not public' });
        }
        if (
            req.user &&
            req.user.role !== 'admin' &&
            !missingPerson.privacySettings.sharePublicly &&
            !missingPerson.privacySettings.shareWithTrusted &&
            missingPerson.reporter.toString() !== req.user.id
        ) {
            return res.status(403).json({ message: 'Access denied: Insufficient permissions' });
        }

        const updates = await Update.find({ missingPerson: missingPersonId })
            .populate('author', 'name role')
            .sort({ createdAt: -1 }) // Newest first
            .lean();

        res.json(updates);
    } catch (err) {
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

module.exports = { createUpdate, getUpdates };