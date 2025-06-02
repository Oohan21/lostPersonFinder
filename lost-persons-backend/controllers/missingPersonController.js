const MissingPerson = require('../models/MissingPerson');
const User = require('../models/User'); // Add this import
const Notification = require('../models/Notification');
const mongoose = require('mongoose');

const createMissingPerson = async (req, res) => {
    try {
        console.log('Create missing person request body:', req.body);
        const missingFields = [];
        if (!req.body.name) missingFields.push('name');
        if (!req.body.age) missingFields.push('age');
        if (!req.body.phone) missingFields.push('phone');
        if (!req.body.gender) missingFields.push('gender');
        if (missingFields.length > 0) {
            return res.status(400).json({ message: `Missing required fields: ${missingFields.join(', ')}` });
        }

        const missingPerson = new MissingPerson({
            ...req.body,
            createdBy: req.user.id,
        });
        await missingPerson.save();

        const users = await User.find(); // Adjust to filter admins if needed, e.g., User.find({ role: 'admin' })
        const notifications = users.map(user => new Notification({
            userId: user._id, // Use _id instead of id for consistency
            message: `New missing person report "${missingPerson.name}" has been submitted (Report ID: ${missingPerson.reportId}).`,
            type: 'report',
            reportId: missingPerson._id, // Use _id instead of id
            createdAt: new Date(),
        }));
        await Promise.all(notifications.map(notification => notification.save()));
        console.log(`Notifications sent for new report: ${missingPerson.reportId}`);

        res.status(201).json(missingPerson);
    } catch (err) {
        console.error('Create missing person error:', err);
        if (err.code === 11000) {
            return res.status(409).json({ message: 'Duplicate reportId detected' });
        }
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

const getMissingPersons = async (req, res) => {
    try {
        const { page = 1, limit = 10, name, ageMin, ageMax, gender, location, radius, myPosts } = req.query;
        const query = {};

        if (name) query.name = { $regex: name, $options: 'i' };
        if (ageMin) query.age = { ...query.age, $gte: parseInt(ageMin) };
        if (ageMax) query.age = { ...query.age, $lte: parseInt(ageMax) };
        if (gender) query.gender = gender;
        if (myPosts === 'true') query.createdBy = req.user.id;

        if (location && radius) {
            const [lat, lon] = location.split(',').map(coord => parseFloat(coord.trim()));
            query['lastSeen.coordinates'] = {
                $geoWithin: {
                    $centerSphere: [[lon, lat], parseFloat(radius) / 6378.1],
                },
            };
        }

        const missingPersons = await MissingPerson.find(query)
            .skip((parseInt(page) - 1) * parseInt(limit))
            .limit(parseInt(limit))
            .populate('createdBy', 'name email');

        const total = await MissingPerson.countDocuments(query);
        const pages = Math.ceil(total / parseInt(limit));

        res.json({
            missingPersons,
            pagination: { page: parseInt(page), limit: parseInt(limit), pages, total },
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

const getMissingPersonById = async (req, res) => {
    try {
        if (!req.user || !req.user.id) {
            console.error('MissingPerson controller: req.user is undefined');
            return res.status(401).json({ message: 'Unauthorized: No user found' });
        }

        const reportId = req.params.id;
        if (!mongoose.Types.ObjectId.isValid(reportId)) {
            console.error('MissingPerson controller: Invalid reportId', reportId);
            return res.status(400).json({ message: 'Invalid reportId' });
        }

        const report = await MissingPerson.findById(reportId).populate('createdBy', 'name id');
        if (!report) {
            console.error('MissingPerson controller: Report not found', reportId);
            return res.status(404).json({ message: 'Report not found' });
        }

        // Check if user is admin or the creator of the report
        const userRole = req.user.role; // Assumes role is set in authMiddleware
        const isCreator = report.createdBy?.id.toString() === req.user.id;
        if (userRole !== 'admin' && !isCreator) {
            console.error('MissingPerson controller: Unauthorized access', { userId: req.user.id, reportId });
            return res.status(403).json({ message: 'Unauthorized' });
        }

        res.status(200).json({
            id: report.id?.toString() || '',
            name: report.name || 'Unknown',
            createdBy: report.createdBy ? {
                id: report.createdBy.id?.toString() || '',
                name: report.createdBy.name || 'Unknown',
            } : null,
        });
    } catch (error) {
        console.error('Get missing person error:', error.message, error.stack);
        res.status(500).json({ message: 'Server error', error: error.message });
    }
};

const updateMissingPerson = async (req, res) => {
    try {
        const reportId = req.params.id;
        console.log(`Update - Attempting to update report with ID: ${reportId}, body: ${JSON.stringify(req.body)}`);

        const missingPerson = await MissingPerson.findById(reportId).populate('createdBy', 'name id');
        if (!missingPerson) {
            console.log(`Update - Report not found: ${reportId}`);
            return res.status(404).json({ message: 'Missing person not found' });
        }
        if (missingPerson.createdBy._id.toString() !== req.user.id) {
            console.log(`Update - Unauthorized access to report: ${reportId}`);
            return res.status(403).json({ message: 'Unauthorized' });
        }

        Object.assign(missingPerson, req.body);
        await missingPerson.save();
        console.log(`Update - Report updated successfully: ${reportId}`);

        // Notify the creator
        const notification = new Notification({
            userId: missingPerson.createdBy._id,
            message: `Your missing person report "${missingPerson.name}" (Report ID: ${missingPerson.reportId}) has been updated.`,
            type: 'report',
            reportId: missingPerson._id,
            createdAt: new Date(),
        });
        await notification.save();
        console.log(`Notification sent for updated report: ${missingPerson.reportId}`);

        res.json(missingPerson);
    } catch (err) {
        console.error('Update report error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

const deleteMissingPerson = async (req, res) => {
    try {
        const reportId = req.params.id;
        console.log(`Delete - Attempting to delete report with ID: ${reportId}`);

        const missingPerson = await MissingPerson.findOne({ _id: reportId, createdBy: req.user.id }).populate('createdBy', 'name id');
        if (!missingPerson) {
            console.log(`Delete - Report not found or unauthorized: ${reportId}`);
            return res.status(404).json({ message: 'Missing person not found or unauthorized' });
        }

        await MissingPerson.findByIdAndDelete(reportId);
        console.log(`Delete - Report deleted successfully: ${reportId}`);

        // Notify the creator
        const notification = new Notification({
            userId: missingPerson.createdBy._id,
            message: `Your missing person report "${missingPerson.name}" (Report ID: ${missingPerson.reportId}) has been deleted.`,
            type: 'report',
            reportId: missingPerson._id,
            createdAt: new Date(),
        });
        await notification.save();
        console.log(`Notification sent for deleted report: ${missingPerson.reportId}`);

        res.json({ message: 'Missing person deleted' });
    } catch (err) {
        console.error('Delete report error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

const updateReportStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const { status } = req.body;

        console.log('Updating report status:', { id, status });

        if (!mongoose.Types.ObjectId.isValid(id)) {
            return res.status(400).json({ message: 'Invalid report ID' });
        }

        if (!['active', 'resolved'].includes(status)) {
            return res.status(400).json({ message: 'Invalid status' });
        }

        const report = await MissingPerson.findById(id).populate('createdBy', 'name id');
        if (!report) {
            return res.status(404).json({ message: 'Report not found' });
        }

        if (req.user.role !== 'admin') {
            return res.status(403).json({ message: 'Admin access required' });
        }

        report.status = status;
        await report.save();

        // Notify the creator
        const notification = new Notification({
            userId: report.createdBy._id,
            message: `The status of your missing person report "${report.name}" (Report ID: ${report.reportId}) has been updated to "${status}".`,
            type: 'report',
            reportId: report._id,
            createdAt: new Date(),
        });
        await notification.save();
        console.log(`Notification sent for status update of report: ${report.reportId}`);

        console.log('Report status updated:', { id, status });
        res.status(200).json({ message: 'Report status updated', report });
    } catch (err) {
        console.error('Update report status error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

module.exports = {
    createMissingPerson,
    getMissingPersons,
    getMissingPersonById,
    updateMissingPerson,
    deleteMissingPerson,
    updateReportStatus,
};