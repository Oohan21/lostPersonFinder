// sightingController.js
const mongoose = require('mongoose');
const Sighting = require('../models/Sighting');
const MissingPerson = require('../models/MissingPerson');
const path = require('path');
const fs = require('fs');

// Ensure uploads directory exists
const uploadDir = path.join(__dirname, '..', 'Uploads');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

// Create a new sighting
exports.createSighting = async (req, res) => {
    try {
        const { description, dateTime, address, name, phone, email, coordinates } = req.body;
        const reportId = req.params.id;

        console.log('Creating sighting for reportId:', reportId);
        console.log('Request body:', req.body);

        // Validate required fields
        if (!reportId || !description || !dateTime) {
            return res.status(400).json({ message: 'reportId, description, and dateTime are required' });
        }

        // Validate reportId
        if (!mongoose.Types.ObjectId.isValid(reportId)) {
            return res.status(400).json({ message: 'Invalid reportId' });
        }

        // Validate dateTime
        const parsedDateTime = new Date(dateTime);
        if (isNaN(parsedDateTime.getTime())) {
            return res.status(400).json({ message: 'Invalid dateTime format' });
        }

        // Parse coordinates if provided
        let parsedCoordinates;
        if (coordinates) {
            try {
                parsedCoordinates = JSON.parse(coordinates);
                if (!Array.isArray(parsedCoordinates) || parsedCoordinates.length !== 2) {
                    return res.status(400).json({ message: 'Coordinates must be an array of [lng, lat]' });
                }
                const [lng, lat] = parsedCoordinates;
                if (lng < -180 || lng > 180 || lat < -90 || lat > 90) {
                    return res.status(400).json({ message: 'Invalid coordinates: lng (-180 to 180), lat (-90 to 90)' });
                }
            } catch (e) {
                return res.status(400).json({ message: 'Invalid coordinates format' });
            }
        }

        // Handle image uploads
        const photos = req.files && req.files.length > 0
            ? req.files.map(file => file.path.replace(/^Uploads[\\/]/, '').replace(/\\/g, '/'))
            : [];

        // Build sighting object
        const sightingData = {
            reportId,
            description,
            location: {
                dateTime: parsedDateTime,
                address: address || null,
                ...(parsedCoordinates && {
                    coordinates: {
                        type: 'Point',
                        coordinates: parsedCoordinates,
                    },
                }),
            },
            contactInfo: {
                ...(name && { name }),
                ...(phone && { phone }),
                ...(email && { email }),
            },
            photos,
            createdBy: req.user.id,
            status: 'pending',
        };

        const sighting = new Sighting(sightingData);
        await sighting.save();
        const report = await MissingPerson.findById(reportId).populate('createdBy', 'name _id');
        if (report && report.createdBy && report.createdBy.id.toString() !== req.user.id) {
            const creator = await User.findById(req.user.id).select('name');
            const notification = new Notification({
                userId: report.createdBy.id,
                message: `New sighting reported by ${creator.name} for ${report.name || 'a missing person'}`,
                type: 'sighting',
                reportId,
                otherParticipantName: creator.name,
            });
            await notification.save();
        }
        console.log('Sighting saved:', { reportId, sightingId: sighting.id, photos });
        res.status(201).json({ message: 'Sighting reported', sighting });
    } catch (err) {
        console.error('Create sighting error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Get sightings for a report
exports.getSightings = async (req, res) => {
    try {
        const reportId = req.params.id;
        console.log('Fetching sightings for reportId:', reportId);

        // Validate reportId
        if (!mongoose.Types.ObjectId.isValid(reportId)) {
            return res.status(400).json({ message: 'Invalid reportId' });
        }

        // Check if report exists
        const report = await MissingPerson.findById(reportId);
        if (!report) {
            return res.status(404).json({ message: 'Report not found' });
        }

        const sightings = await Sighting.find({ reportId })
            .populate('createdBy', 'name email')
            .sort({ createdAt: -1 });

        res.status(200).json(sightings);
    } catch (err) {
        console.error('Get sightings error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Update an existing sighting
exports.updateSighting = async (req, res) => {
    try {
        const { id } = req.params;
        const { description, dateTime, address, name, phone, email, coordinates } = req.body;

        console.log('Updating sighting:', id);
        console.log('Request body:', req.body);

        // Validate sighting ID
        if (!mongoose.Types.ObjectId.isValid(id)) {
            return res.status(400).json({ message: 'Invalid sighting ID' });
        }

        // Find the sighting
        const sighting = await Sighting.findById(id);
        if (!sighting) {
            return res.status(404).json({ message: 'Sighting not found' });
        }

        // Check if user is authorized (createdBy or admin)
        if (sighting.createdBy.toString() !== req.user.id && req.user.role !== 'admin') {
            return res.status(403).json({ message: 'Unauthorized to update this sighting' });
        }

        // Validate required fields
        if (!description || !dateTime) {
            return res.status(400).json({ message: 'description and dateTime are required' });
        }

        // Validate dateTime
        const parsedDateTime = new Date(dateTime);
        if (isNaN(parsedDateTime.getTime())) {
            return res.status(400).json({ message: 'Invalid dateTime format' });
        }

        // Parse coordinates if provided
        let parsedCoordinates;
        if (coordinates) {
            try {
                parsedCoordinates = JSON.parse(coordinates);
                if (!Array.isArray(parsedCoordinates) || parsedCoordinates.length !== 2) {
                    return res.status(400).json({ message: 'Coordinates must be an array of [lng, lat]' });
                }
                const [lng, lat] = parsedCoordinates;
                if (lng < -180 || lng > 180 || lat < -90 || lat > 90) {
                    return res.status(400).json({ message: 'Invalid coordinates: lng (-180 to 180), lat (-90 to 90)' });
                }
            } catch (e) {
                return res.status(400).json({ message: 'Invalid coordinates format' });
            }
        }

        // Handle image uploads (replace existing photos if new ones are provided)
        let photos = sighting.photos;
        if (req.files && req.files.length > 0) {
            // Delete old photos from filesystem
            for (const photoPath of sighting.photos) {
                try {
                    const fullPath = path.join(__dirname, '..', 'Uploads', photoPath);
                    if (fs.existsSync(fullPath)) {
                        fs.unlinkSync(fullPath);
                        console.log(`Deleted old photo: ${photoPath}`);
                    }
                } catch (e) {
                    console.warn(`Failed to delete old photo ${photoPath}:`, e);
                }
            }
            photos = req.files.map(file => file.path.replace(/^Uploads[\\/]/, '').replace(/\\/g, '/'));
        }

        // Update sighting data
        sighting.description = description;
        sighting.location = {
            dateTime: parsedDateTime,
            address: address || null,
            ...(parsedCoordinates && {
                coordinates: {
                    type: 'Point',
                    coordinates: parsedCoordinates,
                },
            }),
        };
        sighting.contactInfo = {
            ...(name && { name }),
            ...(phone && { phone }),
            ...(email && { email }),
        };
        sighting.photos = photos;

        await sighting.save();

        console.log('Sighting updated:', sighting._id);
        res.status(200).json({ message: 'Sighting updated successfully', sighting });
    } catch (error) {
        console.error('Error updating sighting:', error);
        res.status(500).json({ message: 'Server error', error: error.message });
    }
};

// Update sighting status
exports.updateSightingStatus = async (req, res) => {
    try {
        const { sightingId } = req.params;
        const { status } = req.body;

        console.log('Updating sighting status:', { sightingId, status });

        if (!mongoose.Types.ObjectId.isValid(sightingId)) {
            return res.status(400).json({ message: 'Invalid sightingId' });
        }

        if (!['pending', 'verified', 'rejected'].includes(status)) {
            return res.status(400).json({ message: 'Invalid status' });
        }

        const sighting = await Sighting.findById(sightingId);
        if (!sighting) {
            return res.status(404).json({ message: 'Sighting not found' });
        }

        if (req.user.role !== 'admin') {
            return res.status(403).json({ message: 'Admin access required' });
        }

        sighting.status = status;
        await sighting.save();

        console.log('Sighting status updated:', { sightingId, status });
        res.status(200).json({ message: 'Sighting status updated', sighting });
    } catch (err) {
        console.error('Update sighting status error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};