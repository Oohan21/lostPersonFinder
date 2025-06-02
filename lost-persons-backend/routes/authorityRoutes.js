const express = require('express');
const { getAuthorityContacts, submitReportToAuthority, manageSystem } = require('../controllers/authorityController');
const { authMiddleware, adminMiddleware } = require('../middleware/authMiddleware');

const router = express.Router();

// Routes
router.get('/contacts', getAuthorityContacts);
router.post('/submit-report/:reportId', authMiddleware, submitReportToAuthority);
router.post('/manage', authMiddleware, adminMiddleware, manageSystem);

module.exports = router;