const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const dotenv = require('dotenv');
const morgan = require('morgan');
const multer = require('multer');
const rateLimit = require('express-rate-limit');
const path = require('path');
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const missingPersonRoutes = require('./routes/missingPersonRoutes');
const updateRoutes = require('./routes/updateRoutes');
const sightingRoutes = require('./routes/sightingRoutes');
const messageRoutes = require('./routes/messageRoutes');
const conversationRoutes = require('./routes/conversationRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
// Load environment variables
dotenv.config();

const app = express();

// Security Middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            imgSrc: ["'self'", "data:", "http://localhost:3000"],
            connectSrc: ["'self'", "http://localhost:3000"],
        },
    },
    crossOriginResourcePolicy: { policy: "cross-origin" },
}));

// CORS Configuration
app.use(cors());

// Request Logging
app.use(morgan('combined'));

// Rate Limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Limit each IP to 100 requests per windowMs
    message: { error: 'Too many requests from this IP, please try again later' },
});
app.use('/api/', limiter);

// Body Parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Serve Static Files
const uploadsPath = path.join(__dirname, 'uploads');
app.use('/uploads', express.static(uploadsPath, {
    setHeaders: (res, path) => {
        res.set('Cache-Control', 'public, max-age=31536000');
    },
}));
// Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/missing-persons', missingPersonRoutes);
app.use('/api/missing-persons/:id/updates', updateRoutes);
app.use('/api/missing-persons/:id/sightings', sightingRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/conversations', conversationRoutes);
app.use('/api/notifications', notificationRoutes);

// Health Check Endpoint
app.get('/api/health', (req, res) => {
    res.status(200).json({ status: 'OK', uptime: process.uptime() });
});

// Global Error Handling
app.use((err, req, res, next) => {
    console.error('Error:', err.stack);
    if (err instanceof multer.MulterError) {
        return res.status(400).json({ message: 'File upload error', error: err.message });
    }
    if (err.message.includes('Only images are allowed')) {
        return res.status(400).json({ message: err.message });
    }
    res.status(500).json({ message: 'Server error', error: err.message });
});

// MongoDB Connection
const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/lost_persons';
mongoose.connect(mongoUri, {
    serverSelectionTimeoutMS: 5000,
})
    .then(() => console.log('MongoDB connected to lost_persons'))
    .catch((err) => {
        console.error('MongoDB connection error:', err);
        process.exit(1);
    });

// Start Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});