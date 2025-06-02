const Message = require('../models/Message');
const Conversation = require('../models/Conversation');
const Notification = require('../models/Notification');
const MissingPerson = require('../models/MissingPerson');
const User = require('../models/User');
const mongoose = require('mongoose');

exports.sendMessage = async (req, res) => {
    try {
        const { reportId, content } = req.body;
        const senderId = req.user?.id;

        if (!senderId) {
            return res.status(401).json({ message: 'Unauthorized: No user ID found' });
        }

        if (!reportId || !content) {
            return res.status(400).json({ message: 'reportId and content are required' });
        }

        const report = await MissingPerson.findOne({ reportId }).populate('createdBy', 'name email id');
        if (!report || !report.createdBy?.id) {
            return res.status(404).json({ message: 'Report or report creator not found' });
        }

        let conversation = await Conversation.findOne({ reportId });
        if (!conversation) {
            conversation = new Conversation({
                reportId,
                participants: [
                    { id: senderId },
                    { id: report.createdBy.id },
                ],
                report: {
                    id: report.id,
                    name: report.name || 'Missing Person',
                },
            });
        } else {
            const isParticipant = conversation.participants.some(p =>
                p.id && senderId && p.id.toString() === senderId.toString()
            );
            if (!isParticipant) {
                conversation.participants.push({ id: senderId });
            }
        }

        const message = new Message({
            conversationId: conversation.id,
            reportId,
            sender: senderId,
            content,
        });

        conversation.lastMessage = {
            content,
            sender: senderId,
            createdAt: message.createdAt,
        };

        await message.save();
        await conversation.save();

        if (report.createdBy.id.toString() !== senderId.toString()) {
            const sender = await User.findById(senderId).select('name');
            const notification = new Notification({
                userId: report.createdBy.id,
                message: `New message from ${sender.name} about report ${reportId}`,
                type: 'message',
                reportId,
                conversationId: conversation.id,
                otherParticipantName: sender.name,
            });
            await notification.save();
        }

        res.status(201).json({
            id: message.id.toString(),
            conversationId: message.conversationId.toString(),
            reportId: message.reportId.toString(),
            sender: {
                id: senderId.toString(),
                name: report.createdBy.id.toString() === senderId.toString() ? report.createdBy.name : 'Unknown',
            },
            content: message.content,
            createdAt: message.createdAt,
        });
    } catch (err) {
        console.error('Send message error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

exports.getMessages = async (req, res) => {
    try {
        const conversationId = req.params.conversationId;
        const userId = req.user?.id;

        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized: No user ID found' });
        }

        if (!mongoose.isValidObjectId(conversationId)) {
            return res.status(400).json({ message: 'Invalid conversationId format' });
        }

        const conversation = await Conversation.findById(conversationId);
        if (!conversation) {
            return res.status(404).json({ message: 'Conversation not found' });
        }

        const isParticipant = conversation.participants.some(p =>
            p.id && userId && p.id.toString() === userId.toString()
        );
        if (!isParticipant) {
            return res.status(403).json({ message: 'Unauthorized: User is not a participant' });
        }

        const messages = await Message.find({ conversationId })
            .populate('sender', 'name email id')
            .sort({ createdAt: 1 });

        res.status(200).json(
            messages.map(msg => ({
                id: msg.id.toString(),
                conversationId: msg.conversationId.toString(),
                reportId: msg.reportId.toString(),
                sender: {
                    id: msg.sender.id.toString(),
                    name: msg.sender.name || 'Unknown',
                    email: msg.sender.email || '',
                },
                content: msg.content,
                createdAt: msg.createdAt,
            }))
        );
    } catch (err) {
        console.error('Get messages error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};