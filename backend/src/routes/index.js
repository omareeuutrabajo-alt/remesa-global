'use strict';
const router = require('express').Router();
const env = require('../config/env');

router.get('/', (_req, res) => res.json({
  success: true,
  data: {
    name: 'Remesas Auth API',
    version: '1.0.0',
    environment: env.nodeEnv,
    endpoints: {
      auth: `${env.apiPrefix}/auth`,
      kyc: `${env.apiPrefix}/kyc`,
      docs: '/docs',
      health: '/health',
    },
  },
}));

router.use('/auth', require('./auth.routes'));
router.use('/kyc', require('./kyc.routes'));

module.exports = router;
