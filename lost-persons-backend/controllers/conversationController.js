const Conversation = require('../models/Conversation');
const MissingPerson = require('../models/MissingPerson');
const mongoose = require('mongoose');

exports.createConversation = async (req, res) => {
    try {
        const { reportId, participantIds } = req.body;
        const creatorId = req.user?.id;

        if (!creatorId) {
            return res.status(401).json({ message: 'Unauthorized: No user ID found' });
        }

        if (!reportId || !participantIds || !Array.isArray(participantIds) || participantIds.length === 0) {
            return res.status(400).json({ message: 'reportId and participantIds (array with at least one ID) are required' });
        }

        const validParticipantIds = participantIds.filter(id => id && typeof id === 'string');
        if (validParticipantIds.length === 0) {
            return res.status(400).json({ message: 'No valid participant IDs provided' });
        }

        const report = await MissingPerson.findOne({ reportId }).populate('createdBy', 'name id');
        if (!report || !report.createdBy?.id) {
            return res.status(404).json({ message: 'Report or report creator not found' });
        }

        const participants = [...new Set([creatorId, ...validParticipantIds])].map(id => ({ id: id }));

        let conversation = await Conversation.findOne({
            reportId,
            participants: { $all: participants.map(p => ({ id: p.id })) },
        });

        if (conversation) {
            return res.status(200).json({
                id: conversation.id.toString(),
                reportId: conversation.reportId.toString(),
                participants: conversation.participants.map(p => ({
                    id: p.id.toString(),
                    name: report.createdBy.id.toString() === p.id.toString() ? report.createdBy.name : 'Unknown',
                    email: report.createdBy.id.toString() === p.id.toString() ? report.createdBy.email : '',
                })),
                report: {
                    id: conversation.report.id.toString(),
                    name: conversation.report.name,
                },
            });
        }

        conversation = new Conversation({
            reportId,
            participants,
            report: {
                id: report.id,
                name: report.name || 'Missing Person',
            },
        });

        await conversation.save();

        res.status(201).json({
            id: conversation.id.toString(),
            reportId: conversation.reportId.toString(),
            participants: conversation.participants.map(p => ({
                id: p.id.toString(),
                name: report.createdBy && p.id && report.createdBy.id.toString() === p.id.toString()
                    ? report.createdBy.name || 'Unknown'
                    : p.id?.name || 'Unknown',
            })),
            report: {
                id: conversation.report.id.toString(),
                name: conversation.report.name,
            },
        });
    } catch (err) {
        console.error('Create conversation error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

exports.getConversation = async (req, res) => {
    try {
        const conversationId = req.params.conversationId;
        const userId = req.user?.id;

        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized: No user ID found' });
        }

        const conversation = await Conversation.findById(conversationId)
            .populate('participants.id', 'name email')
            .populate('report.id', 'name');

        if (!conversation) {
            return res.status(404).json({ message: 'Conversation not found' });
        }

        const isParticipant = conversation.participants.some(p =>
            p.id && userId && p.id.toString() === userId.toString()
        );
        if (!isParticipant) {
            return res.status(403).json({ message: 'Unauthorized: User is not a participant' });
        }

        res.status(200).json({
            id: conversation.id.toString(),
            reportId: conversation.reportId.toString(),
            participants: conversation.participants.map(p => ({
                id: p.id.toString(),
                name: p.id.name || 'Unknown',
                email: p.id.email || '',
            })),
            report: {
                id: conversation.report.id.toString(),
                name: conversation.report.name,
            },
        });
    } catch (err) {
        console.error('Get conversation error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

exports.getConversations = async (req, res) => {
    try {
        if (!req.user || !req.user.id) {
            console.error('Conversation controller: req.user is undefined');
            return res.status(401).json({ message: 'Unauthorized: No user found' });
        }

        const query = { participants: { $elemMatch: { id: req.user.id } } };
        if (req.query.reportId) {
            query.reportId = req.query.reportId;
        }

        const conversations = await Conversation.find(query)
            .populate('participants.id', 'name')
            .sort({ updatedAt: -1 });

        res.status(200).json(
            conversations.map(conv => ({
                id: conv.id?.toString() || '',
                reportId: conv.reportId?.toString() || '',
                reportName: conv.report?.name || 'Unknown',
                participants: conv.participants.map(p => ({
                    id: p.id?.toString() || '',
                    name: p.id?.toString() === req.user.id ? 'You' : p.name || 'Unknown',
                })),
                lastMessage: conv.lastMessage
                    ? {
                        content: conv.lastMessage.content || '',
                        sender: conv.lastMessage.sender?.toString() || '',
                        createdAt: conv.lastMessage.createdAt?.toISOString() || '',
                    }
                    : null,
            })),
        );
    } catch (error) {
        console.error('Get conversations error:', error.message, error.stack);
        res.status(500).json({ message: 'Server error', error: error.message });
    }
};

exports.getOrCreateConversation = async (req, res) => {
    try {
        if (!req.user || !req.user.id) {
            console.error('Conversation controller: req.user is undefined');
            return res.status(401).json({ message: 'Unauthorized: No user found' });
        }

        const { reportId, participantIds } = req.body;
        if (!reportId || !Array.isArray(participantIds) || participantIds.length === 0) {
            console.error('Conversation controller: Invalid request body', { reportId, participantIds });
            return res.status(400).json({ message: 'reportId and participantIds (array with at least one ID) are required' });
        }

        const report = await MissingPerson.findOne({ reportId }).populate('createdBy', 'name id');
        if (!report) {
            console.error('Conversation controller: Report not found', reportId);
            return res.status(404).json({ message: 'Report not found' });
        }

        // Log report.createdBy to debug population
        console.log('Report createdBy:', report.createdBy);

        if (!report.createdBy?.id) {
            console.error('Conversation controller: Report missing createdBy', { reportId, report });
            return res.status(400).json({ message: 'Report missing creator information' });
        }

        const allParticipantIds = [...new Set([req.user.id, ...participantIds])];

        let conversation = await Conversation.findOne({
            reportId,
            participants: { $all: allParticipantIds.map(id => ({ id: id })) },
        });

        if (!conversation) {
            conversation = new Conversation({
                reportId,
                participants: allParticipantIds.map(id => ({ id: id })),
                report: {
                    id: report.id,
                    name: report.name || 'Missing Person',
                },
            });
            await conversation.save();
            if (!conversation.id) {
                console.error('Conversation controller: Failed to save conversation', { reportId, participantIds });
                return res.status(500).json({ message: 'Failed to create conversation' });
            }
            console.log('Conversation controller: Created new conversation', conversation.id.toString());
        }

        // Ensure participants are populated
        await conversation.populate('participants.id', 'name');

        // Log participants for debugging
        console.log('Conversation participants:', conversation.participants);

        res.status(201).json({
            id: conversation.id?.toString() || '',
            reportId: conversation.reportId?.toString() || '',
            participants: conversation.participants.map(p => {
                const participantId = p.id?.toString() || '';
                const creatorId = report.createdBy?.id?.toString();
                return {
                    id: participantId,
                    name: creatorId && participantId === creatorId
                        ? report.createdBy.name || 'Unknown'
                        : p.id?.name || 'Unknown',
                };
            }),
        });
    } catch (error) {
        console.error('Get or create conversation error:', error.message, error.stack);
        res.status(500).json({ message: 'Server error', error: error.message });
    }
};