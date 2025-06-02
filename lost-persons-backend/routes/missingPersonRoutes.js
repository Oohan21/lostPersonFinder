const express = require('express');
const router = express.Router();
const auth = require('../middleware/authMiddleware');
const {
    createMissingPerson,
    getMissingPersons,
    getMissingPersonById,
    updateMissingPerson,
    deleteMissingPerson,
    updateReportStatus,
} = require('../controllers/missingPersonController');

router.post('/', auth, createMissingPerson);
router.get('/', auth, getMissingPersons);
router.get('/:id', auth, getMissingPersonById);
router.put('/:id', auth, updateMissingPerson);
router.delete('/:id', auth, deleteMissingPerson);
router.patch('/:id/', auth, updateReportStatus);
module.exports = router;