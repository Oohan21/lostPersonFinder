// sightingRoutes.js
const express = require('express');
const router = express.Router({ mergeParams: true });
const auth = require('../middleware/authMiddleware');
const upload = require('../middleware/multerConfig');
const { createSighting, getSightings, updateSighting, updateSightingStatus } = require('../controllers/sightingController');

router.post('/', auth, upload.array('photos', 5), createSighting);
router.get('/', auth, getSightings);
router.patch('/:id', auth, upload.array('photos', 5), updateSighting);
router.patch('/:sightingId/status', auth, updateSightingStatus);

module.exports = router;