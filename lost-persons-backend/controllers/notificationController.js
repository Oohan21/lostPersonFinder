const Notification = require('../models/Notification');

exports.getNotifications = async (req, res) => {
    try {
        const userId = req.user.id;
        const notifications = await Notification.find({ userId })
            .sort({ createdAt: -1 })
            .limit(50);

        res.status(200).json(notifications);
    } catch (err) {
        console.error('Get notifications error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

exports.markNotificationAsRead = async (req, res) => {
    try {
        const userId = req.user.id;
        const notificationId = req.params.notificationId;

        const notification = await Notification.findOneAndUpdate(
            { id: notificationId, userId },
            { read: true },
            { new: true }
        );

        if (!notification) {
            return res.status(404).json({ message: 'Notification not found or unauthorized' });
        }

        res.status(200).json(notification);
    } catch (err) {
        console.error('Mark notification as read error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};