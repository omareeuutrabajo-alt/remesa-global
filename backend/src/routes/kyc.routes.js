'use strict';
const router = require('express').Router();
const c = require('../controllers/kycController');
const s = require('../controllers/schemas');
const validate = require('../middleware/validate');
const { requireAuth } = require('../middleware/auth');
const { kycUpload } = require('../middleware/upload');
const env = require('../config/env');

router.use(requireAuth);

router.post('/submit', kycUpload, validate(s.kycSubmit), c.submit);
router.get('/status', c.status);
router.get('/limits', c.limits);

// Atajo de desarrollo para forzar la resolución del expediente.
if (!env.isProd) router.post('/_simulate-review', c.review);

module.exports = router;
